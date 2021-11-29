const { ethers } = require("hardhat")
const { expect } = require("chai")

const { prepare, deploy, getBigNumber, createSLP } = require("./utilities")
const { advanceBlock } = require("./utilities/time")
const { BigNumber } = ethers


// yarn test test/FateRewardControllerV3.test.js
describe("FateRewardControllerV3", () => {
    const epoch_period_blocks = 30 * 60 * 24 * 7 * 9 // 8 weeks

    const doDeposit = async (depositore, depositAmount) => {
      const beforeBalance = await this.lp.balanceOf(depositore.address)
      await this.fateRewardControllerV3.connect(depositore).deposit(0, depositAmount)
      const afterBalance = await this.lp.balanceOf(depositore.address)
      // confirm balance change after deposit
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
      this.RewardSchedule = await ethers.getContractFactory("RewardSchedule")
      this.MockLpTokenFactory = await ethers.getContractFactory("MockLpTokenFactory")
    })
  
    beforeEach(async () => {
      this.fateToken = await this.FateToken.deploy(this.alice.address, getBigNumber(1000))
      await this.fateToken.deployed()

      await this.fateToken.connect(this.alice).transfer(this.bob.address, getBigNumber(100))
      await this.fateToken.connect(this.alice).transfer(this.dev.address, getBigNumber(100))

      this.lp = await this.LP.deploy('lp', 'LP', getBigNumber(1000))
      await this.lp.deployed()

      this.rewardSchedule = await this.RewardSchedule.deploy()
      await this.rewardSchedule.deployed()

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
        this.mockLpTokenFactory.address,
        epoch_period_blocks
      )
      await this.fateRewardControllerV3.deployed()

      // add pool
      await this.fateRewardControllerV3.add(1, this.lp.address, true)

      await this.lp.connect(this.alice).transfer(this.bob.address, getBigNumber(100))
      await this.lp.connect(this.bob).approve(this.fateRewardControllerV3.address, getBigNumber(100))
      await this.lp.connect(this.alice).transfer(this.dev.address, getBigNumber(100))
      await this.lp.connect(this.dev).approve(this.fateRewardControllerV3.address, getBigNumber(100))
      await this.lp.transfer(this.fateRewardControllerV3.address, getBigNumber(10)) 

      // prepare vault
      await this.fateRewardControllerV3.setVault(this.vault.address)

      await this.fateToken.transfer(this.vault.address, getBigNumber(100))
      await this.fateToken.connect(this.vault).approve(
        this.fateRewardControllerV3.address,
        getBigNumber(100)
      )
    })

    // it("MembershipReward", async () => {
    //   // do some deposit actions
    //   await doSomeDeposists()

    //   const bobUserPoints = await this.fateRewardControllerV3.userPoints(0, this.bob.address)
    //   const devUserPoints = await this.fateRewardControllerV3.userPoints(0, this.dev.address)

    //   expect(bobUserPoints).to.above(devUserPoints)

    //   await this.fateRewardControllerV3.rank(0)
    //   const bobMembershipInfo = await this.fateRewardControllerV3.userMembershipInfo(
    //     0, this.bob.address
    //   )
    //   const devMembershipInfo = await this.fateRewardControllerV3.userMembershipInfo(
    //     0, this.dev.address
    //   )
    //   expect(bobMembershipInfo.rankedNumber).to.equal(0)
    //   expect(devMembershipInfo.rankedNumber).to.equal(1)
    // })

    describe("LockedRewardsFee", async () => {
      // describe("setLockedRewardsData", async() => {
      //   it("reverted cases:", async() => {
      //     // when trying to set with not-owner
      //     await expect(
      //       this.fateRewardControllerV3.connect(this.dev).setLockedRewardsData(
      //         [30, 60],
      //         [getBigNumber(1), getBigNumber(98, 16)]
      //       )
      //     ).to.be.revertedWith('Ownable: caller is not the owner')

      //     // when trying with invalid input data
      //     await expect(
      //       this.fateRewardControllerV3.setLockedRewardsData([],[])
      //     ).to.be.revertedWith('setLockedRewardsData: invalid input data')

      //     await expect(
      //       this.fateRewardControllerV3.setLockedRewardsData([30, 60],[])
      //     ).to.be.revertedWith('setLockedRewardsData: invalid input data')
      //   }),

      //   it("success cases:", async() => {
      //     await this.fateRewardControllerV3.setLockedRewardsData(
      //       [10, 20],[getBigNumber(1), getBigNumber(98, 16)]
      //     )
      //     const lockedRewardsPeriodBlock = await this.fateRewardControllerV3.lockedRewardsPeriodBlocks(0)
      //     expect(lockedRewardsPeriodBlock).to.be.equal(10)
      //     const lockedRewardsFeePercent = await this.fateRewardControllerV3.lockedRewardsFeePercents(0)
      //     expect(lockedRewardsFeePercent).to.be.equal(getBigNumber(1))
      //   })
      // })

      // describe("excluded Addresses", async () => {
      //   it("reverted cases", async() => {
      //     // when trying to set with not-owner
      //     await expect(
      //       this.fateRewardControllerV3.connect(this.dev).setExcludedAddresses(
      //         [this.alice.address],
      //         [true]
      //       )
      //     ).to.be.revertedWith('Ownable: caller is not the owner')

      //     // when trying with invalid input data
      //     await expect(
      //       this.fateRewardControllerV3.setExcludedAddresses(
      //         [this.alice.address],
      //         []
      //       )
      //     ).to.be.revertedWith('setExcludedAddresses: invalid data')
      //   })

      //   it('success cases', async() => {
      //     const beforeStatus = await this.fateRewardControllerV3.isExcludedAddress(
      //       this.dev.address
      //     )
      //     expect(beforeStatus).to.be.false
      //     await this.fateRewardControllerV3.setExcludedAddresses(
      //       [this.dev.address],
      //       [true]
      //     )
      //     const afterStatus = await this.fateRewardControllerV3.isExcludedAddress(
      //       this.dev.address
      //     )
      //     expect(afterStatus).to.be.true
      //   })
      // })

      it("check math calc", async () => {
        await doSomeDeposists()
        
      })
    })

    // it("LPWithdrawFee", async () => {
    // })
})

