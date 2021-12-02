const { ethers } = require("hardhat")
const { expect } = require("chai")

const { getBigNumber } = require("./utilities")
const { advanceBlock, advanceBlockTo } = require("./utilities/time")
const { BigNumber } = require('@ethersproject/bignumber')


// yarn test test/FateRewardControllerV3.test.js
describe("FateRewardControllerV3", () => {
    const epoch_period_blocks = 30 * 60 * 24 * 7 * 8 // 8 weeks
    const startBlock = 10

    const doDeposit = async (depositor, depositAmount) => {
      const beforeBalance = await this.lp.balanceOf(depositor.address)
      await this.fateRewardControllerV3.connect(depositor).deposit(0, depositAmount)
      const afterBalance = await this.lp.balanceOf(depositor.address)
      expect(beforeBalance.sub(afterBalance)).to.be.equal(depositAmount)
      
    }

    const doSomeDeposists = async () => {
      await doDeposit(this.bob, getBigNumber(10))
      await advanceBlock()
      await advanceBlock()
      await doDeposit(this.dev, getBigNumber(10))
      await advanceBlock()
    }

    before(async () => {
      this.signers = await ethers.getSigners()
      this.alice = this.signers[0]
      this.bob = this.signers[1]
      this.dev = this.signers[2]
      this.vault = this.signers[3]
  
      this.LP = await ethers.getContractFactory("ERC20Mock")
      this.FateToken = await ethers.getContractFactory("FateToken")
      this.FateRewardControllerV2 = await ethers.getContractFactory("FateRewardController")
      this.FateRewardControllerV3 = await ethers.getContractFactory("FateRewardControllerV3")
      this.RewardSchedule = await ethers.getContractFactory("RewardScheduleV3")
      this.MockLpTokenFactory = await ethers.getContractFactory("MockLpTokenFactory")
    })
  
    beforeEach(async () => { 
      this.fateToken = await this.FateToken.deploy(this.alice.address, getBigNumber(1000))
      await this.fateToken.deployed()

      await this.fateToken.connect(this.alice).transfer(this.bob.address, getBigNumber(100))
      await this.fateToken.connect(this.alice).transfer(this.dev.address, getBigNumber(100))

      this.lp = await this.LP.deploy('lp', 'LP', getBigNumber(1000))
      await this.lp.deployed()

      this.rewardSchedule = await this.RewardSchedule.deploy(
        startBlock,
        epoch_period_blocks,
        getBigNumber(8, 17)
      )
      await this.rewardSchedule.deployed()

      await advanceBlockTo(startBlock);

      this.fateRewardControllerV2 = await this.FateRewardControllerV2.deploy(
        this.fateToken.address,
        this.rewardSchedule.address,
        this.vault.address
      )
      await this.fateRewardControllerV2.deployed()

      this.mockLpTokenFactory = await this.MockLpTokenFactory.deploy()
      await this.mockLpTokenFactory.deployed()

      this.fateRewardControllerV3 = await this.FateRewardControllerV3.deploy(
        this.fateToken.address,
        this.rewardSchedule.address,
        this.vault.address,
        [this.fateRewardControllerV2.address],
        this.mockLpTokenFactory.address
      )
      await this.fateRewardControllerV3.deployed()

      // add pool
      await this.fateRewardControllerV3.add(1, this.lp.address, true)
      await this.fateRewardControllerV3.setFatePoolIds([0], [true]);

      await this.lp.connect(this.alice).transfer(this.bob.address, getBigNumber(100))
      await this.lp.connect(this.bob).approve
        (this.fateRewardControllerV3.address,
        await this.lp.balanceOf(this.bob.address) // getBigNumber(100)
      )
      await this.lp.connect(this.alice).transfer(this.dev.address, getBigNumber(100))
      await this.lp.connect(this.dev).approve(
        this.fateRewardControllerV3.address,
        await this.lp.balanceOf(this.dev.address) // getBigNumber(100)
      )
      await this.lp.transfer(this.fateRewardControllerV3.address, getBigNumber(10)) 

      // prepare vault
      await this.fateRewardControllerV3.setVault(this.vault.address)
      await this.fateToken.transfer(this.vault.address, getBigNumber(400))
      await this.fateToken.connect(this.vault).approve(
        this.fateRewardControllerV3.address,
        await this.fateToken.balanceOf(this.vault.address) // getBigNumber(100)
      )
    })

    describe("MembershipReward & WithdrawFees", async () => {
      it("MembershipReward", async () => {
        // do some deposit actions
        await doSomeDeposists()
  
        const bobUserPoints = await this.fateRewardControllerV3.userPoints(0, this.bob.address)
        const devUserPoints = await this.fateRewardControllerV3.userPoints(0, this.dev.address)
        const vaultUserPoints = await this.fateRewardControllerV3.userPoints(0, this.vault.address)
  
        expect(bobUserPoints).to.above(0)
        expect(devUserPoints).to.above(0)
        expect(bobUserPoints).to.above(devUserPoints)
        expect(vaultUserPoints).to.be.equal(0)
      }),

      it("Withdraw", async () => {
        await doSomeDeposists();

        const withdrawAmount = getBigNumber(1);
        const bobBeforeLPAmount = await this.lp.balanceOf(this.bob.address);

        // when withdraw after 5 blocks, lockedRewardFee: 100%, lpWithdrawFee: 18%
        await this.fateRewardControllerV3.connect(this.bob).withdraw(0, withdrawAmount);
        const bobAfterLPAmount = await this.lp.balanceOf(this.bob.address);
        const receivedAmount = bobAfterLPAmount.sub(bobBeforeLPAmount);

        // check received amount after withdraw: withdrawAmount * (100 - lpWithdrawFee)
        expect(receivedAmount).to.be.equal(withdrawAmount.mul(100 - 18).div(100));

        // userLockedRewards should be zero since lockedRewardFee is 100%
        const bobLockedRewards = await this.fateRewardControllerV3.userLockedRewards(0, this.bob.address);
        expect(bobLockedRewards).to.be.equal(0);


        // withdraw all dev
        await this.fateRewardControllerV3.connect(this.dev).withdraw(
          0, getBigNumber(10)
        );
        const beforeDevPoints = await this.fateRewardControllerV3.userPoints(
          0,
          this.dev.address
        )
        await advanceBlock()
        let afterDevPoints = await this.fateRewardControllerV3.userPoints(
          0,
          this.dev.address
        )
        expect(beforeDevPoints).to.be.equal(afterDevPoints);

        // deposit again
        await doDeposit(this.dev, getBigNumber(9))
        await advanceBlock()
        afterDevPoints = await this.fateRewardControllerV3.userPoints(
          0,
          this.dev.address
        )
        expect(afterDevPoints).to.above(beforeDevPoints)
      })
    })

    describe("setLockedRewardsData", async() => {
      it("reverted cases:", async() => {
        // when trying to set with not-owner
        await expect(
          this.fateRewardControllerV3.connect(this.dev).setLockedRewardsData(
            [30, 60],
            [getBigNumber(1), getBigNumber(98, 16)]
          )
        ).to.be.revertedWith('Ownable: caller is not the owner')

        // when trying with invalid input data
        await expect(
          this.fateRewardControllerV3.setLockedRewardsData([],[])
        ).to.be.revertedWith('setLockedRewardsData: invalid input data')

        await expect(
          this.fateRewardControllerV3.setLockedRewardsData([30, 60],[])
        ).to.be.revertedWith('setLockedRewardsData: invalid input data')
      }),

      it("success cases:", async() => {
        await this.fateRewardControllerV3.setLockedRewardsData(
          [10, 20],[getBigNumber(1), getBigNumber(98, 16)]
        )
        const lockedRewardsPeriodBlock = await this.fateRewardControllerV3.lockedRewardsPeriodBlocks(0)
        expect(lockedRewardsPeriodBlock).to.be.equal(10)
        const lockedRewardsFeePercent = await this.fateRewardControllerV3.lockedRewardsFeePercents(0)
        expect(lockedRewardsFeePercent).to.be.equal(getBigNumber(1))
      })
    })

    describe("excluded Addresses", async () => {
      it("reverted cases", async() => {
        // when trying to set with not-owner
        await expect(
          this.fateRewardControllerV3.connect(this.dev).setExcludedAddresses(
            [this.alice.address],
            [true]
          )
        ).to.be.revertedWith('Ownable: caller is not the owner')

        // when trying with invalid input data
        await expect(
          this.fateRewardControllerV3.setExcludedAddresses(
            [this.alice.address],
            []
          )
        ).to.be.revertedWith('setExcludedAddresses: invalid data')
      })

      it('success cases', async() => {
        const beforeStatus = await this.fateRewardControllerV3.isExcludedAddress(
          this.dev.address
        )
        expect(beforeStatus).to.be.false
        await this.fateRewardControllerV3.setExcludedAddresses(
          [this.dev.address],
          [true]
        )
        const afterStatus = await this.fateRewardControllerV3.isExcludedAddress(
          this.dev.address
        )
        expect(afterStatus).to.be.true
      })
    })
})

