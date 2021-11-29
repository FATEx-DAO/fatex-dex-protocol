const { ethers } = require("hardhat")
const { expect } = require("chai")

const { prepare, deploy, getBigNumber, createSLP } = require("./utilities")
const { advanceBlock } = require("./utilities/time")
const { BigNumber } = ethers


// yarn test test/FateRewardControllerV3.test.js
describe("FateRewardControllerV3", () => {
    const epoch_period_blocks = 30 * 60 * 24 * 7 * 9 // 8 weeks

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

    const doDeposit = async (depositore, depositAmount) => {
      const beforeBalance = await this.lp.balanceOf(depositore.address)
      await this.fateRewardControllerV3.connect(depositore).deposit(0, depositAmount)
      const afterBalance = await this.lp.balanceOf(depositore.address)

      // confirm balance change after deposit
      expect(beforeBalance.sub(afterBalance)).to.be.equal(depositAmount)
    }

    it("MembershipReward", async () => {
      await doDeposit(this.bob, getBigNumber(10))
      await advanceBlock()
      await advanceBlock()
      await doDeposit(this.dev, getBigNumber(10))
      await advanceBlock()

      const bobUserPoints = await this.fateRewardControllerV3.userPoints(0, this.bob.address)
      const devUserPoints = await this.fateRewardControllerV3.userPoints(0, this.dev.address)

      expect(bobUserPoints).to.above(devUserPoints)

      await this.fateRewardControllerV3.rank(0)
      const bobMembershipInfo = await this.fateRewardControllerV3.userMembershipInfo(
        0, this.bob.address
      )
      const devMembershipInfo = await this.fateRewardControllerV3.userMembershipInfo(
        0, this.dev.address
      )
      expect(bobMembershipInfo.rankedNumber).to.equal(0);
      expect(devMembershipInfo.rankedNumber).to.equal(1);
    })

    // it("LockedRewardsFee", async () => {
    // })

    // it("LPWithdrawFee", async () => {
    // })
})

