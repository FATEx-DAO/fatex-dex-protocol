const { ethers } = require('hardhat')
const { expect, use } = require('chai')
const { solidity } = require("ethereum-waffle")
const { deployContract } = require("../shared/fixtures")
const { expandDecimals } = require("../shared/utilities")
const time = require('../utilities/time')

use(solidity)

describe('FateRewardControllerV3.MembershipReward and Withdraw', () => {
  let lpToken;
  let fateToken;
  let rewardSchedule;
  let fateRewardControllerV2;
  let fateRewardControllerV3;
  let mockLpTokenFactory;
  let startTimestamp;

  const doDeposit = async (depositor, depositAmount, poolId) => {
    const beforeBalance = await lpToken.balanceOf(depositor.address)
    await fateRewardControllerV3.connect(depositor).deposit(poolId, depositAmount)
    const afterBalance = await lpToken.balanceOf(depositor.address)
    expect(beforeBalance.sub(afterBalance)).to.be.equal(depositAmount)
  }

  before(async () => {
    this.signers = await ethers.getSigners()
    this.alice = this.signers[0]
    this.bob = this.signers[1]
    this.dev = this.signers[2]
    this.vault = this.signers[3]
    this.feeTo = this.signers[4]
  })

  beforeEach(async () => {
    try {
      fateToken = await deployContract('FateToken', [this.alice.address, expandDecimals(1000)])
      await fateToken.connect(this.alice).transfer(this.bob.address, expandDecimals(100))
      await fateToken.connect(this.alice).transfer(this.dev.address, expandDecimals(100))
      lpToken = await deployContract('ERC20Mock', ['lp', 'LP', expandDecimals(1000)])
      rewardSchedule = await deployContract('RewardScheduleV3', [])
      fateRewardControllerV2 = await deployContract('FateRewardController',
        [
          fateToken.address,
          rewardSchedule.address,
          this.vault.address]
      )
      mockLpTokenFactory = await deployContract('MockLpTokenFactory', [])
      fateRewardControllerV3 = await deployContract('FateRewardControllerV3', [
          fateToken.address,
          rewardSchedule.address,
          this.vault.address,
          [fateRewardControllerV2.address],
          mockLpTokenFactory.address,
          this.feeTo.address
        ]
      )
      startTimestamp = await fateRewardControllerV3.startTimestamp()

      // add pool
      await fateRewardControllerV3.add(1, lpToken.address, true)

      await lpToken.connect(this.alice).transfer(this.bob.address, expandDecimals(100))
      await lpToken.connect(this.bob).approve
      (fateRewardControllerV3.address,
        await lpToken.balanceOf(this.bob.address) // expandDecimals(100)
      )
      await lpToken.connect(this.alice).transfer(this.dev.address, expandDecimals(100))
      await lpToken.connect(this.dev).approve(
        fateRewardControllerV3.address,
        await lpToken.balanceOf(this.dev.address) // expandDecimals(100)
      )
      await lpToken.transfer(fateRewardControllerV3.address, expandDecimals(10))

      // prepare vault
      await fateRewardControllerV3.setVault(this.vault.address)
      await fateToken.transfer(this.vault.address, expandDecimals(400))
      await fateToken.connect(this.vault).approve(
        fateRewardControllerV3.address,
        await fateToken.balanceOf(this.vault.address) // expandDecimals(100)
      )
    } catch (e) {
      console.log('INHO')
      console.log(e)
    }
  })

  describe('MembershipReward', async () => {
    it('should work for basic calculations', async () => {
      // do some deposit actions
      await doDeposit(this.bob, expandDecimals(100), 0)

      await time.advanceTime(60)

      const bobUserPoints = await fateRewardControllerV3.userPoints(0, this.bob.address)
      const devUserPoints = await fateRewardControllerV3.userPoints(0, this.dev.address)
      const vaultUserPoints = await fateRewardControllerV3.userPoints(0, this.vault.address)

      expect(bobUserPoints).to.above(0)
      expect(devUserPoints).to.be.equal(0)
      expect(vaultUserPoints).to.be.equal(0)
    })
  })

  describe('Withdrawals', async () => {
    it('should work for < 60 seconds', async () => {
      const depositAmount = expandDecimals(100)
      const withdrawalAmount = expandDecimals(10)
      const expectedLpFee = ethers.BigNumber.from(8800)
      const expectedRewardFee = ethers.BigNumber.from(10000)
      const poolId = 0
      const durationSeconds = 1

      await performWithdrawalTest(
        depositAmount,
        withdrawalAmount,
        expectedLpFee,
        expectedRewardFee,
        poolId,
        durationSeconds,
      )
    })

    it('should work for > 60 seconds <= 120 seconds', async () => {
      const depositAmount = expandDecimals(100)
      const withdrawalAmount = expandDecimals(10)
      const expectedLpFee = ethers.BigNumber.from(7200)
      const expectedRewardFee = ethers.BigNumber.from(9800)
      const poolId = 0
      const durationSeconds = 65

      await performWithdrawalTest(
        depositAmount,
        withdrawalAmount,
        expectedLpFee,
        expectedRewardFee,
        poolId,
        durationSeconds,
      )
    })

    it('should work for > 2937600 seconds <= 3110400 seconds', async () => {
      const depositAmount = expandDecimals(100)
      const withdrawalAmount = expandDecimals(10)
      const expectedLpFee = ethers.BigNumber.from(8)
      const expectedRewardFee = ethers.BigNumber.from(80)
      const poolId = 0
      const durationSeconds = 2937600 + 5

      await performWithdrawalTest(
        depositAmount,
        withdrawalAmount,
        expectedLpFee,
        expectedRewardFee,
        poolId,
        durationSeconds,
      )
    })

    it('should work for > 3110400 seconds', async () => {
      const depositAmount = expandDecimals(100)
      const withdrawalAmount = expandDecimals(10)
      const expectedLpFee = ethers.BigNumber.from(0)
      const expectedRewardFee = ethers.BigNumber.from(0)
      const poolId = 0
      const durationSeconds = 3110405

      await performWithdrawalTest(
        depositAmount,
        withdrawalAmount,
        expectedLpFee,
        expectedRewardFee,
        poolId,
        durationSeconds,
      )
    })

    const performWithdrawalTest = async (
      depositAmount,
      withdrawalAmount,
      expectedLpFee,
      expectedRewardFee,
      poolId,
      durationSeconds,
    ) => {
      await doDeposit(this.bob, depositAmount, poolId)
      const depositTimestamp = await time.latestTimestamp()

      const fateWalletBalanceBefore = await fateToken.balanceOf(this.bob.address)
      const lpWalletBalanceBefore = await lpToken.balanceOf(this.bob.address)

      await time.advanceTime(durationSeconds)

      await fateRewardControllerV3.connect(this.bob).withdraw(poolId, withdrawalAmount)
      const withdrawalTimestamp = await time.latestTimestamp()
      const lpWalletBalanceAfter = await lpToken.balanceOf(this.bob.address)
      const contractBalanceAfter = (await fateRewardControllerV3.userInfo(poolId, this.bob.address)).amount
      const receivedAmount = lpWalletBalanceAfter.sub(lpWalletBalanceBefore)

      // check received amount after withdrawal
      expect(contractBalanceAfter).to.be.eq(depositAmount.sub(withdrawalAmount))
      expect(receivedAmount).to.be.eq(withdrawalAmount.sub(withdrawalAmount.mul(expectedLpFee).div(10000)))

      // check fee is sent to fateFeeTo
      expect(await fateRewardControllerV3.fateFeeTo()).to.be.equal(this.feeTo.address)
      const feeToBalance = await lpToken.balanceOf(this.feeTo.address)
      expect(feeToBalance).to.be.eq(withdrawalAmount.mul(expectedLpFee).div(10000))

      // userLockedRewards should be zero since lockedRewardFee is 100%
      const bobLockedRewards = await fateRewardControllerV3.userLockedRewards(poolId, this.bob.address)
      const rewardsForDuration = await rewardSchedule.getFateForDuration(
        startTimestamp,
        depositTimestamp,
        withdrawalTimestamp,
      )
      const allLockedRewards = rewardsForDuration[0]
      const allUnlockedRewards = rewardsForDuration[1]
      const poolInfo = await fateRewardControllerV3.poolInfo(poolId)
      const totalAllocPoint = await fateRewardControllerV3.totalAllocPoint()
      const lockedRewards = allLockedRewards.mul(poolInfo.allocPoint).div(totalAllocPoint)
      expect(bobLockedRewards).to.be.equal(lockedRewards.sub(lockedRewards.mul(expectedRewardFee).div(10000)))

      const unlockedRewards = allUnlockedRewards.mul(poolInfo.allocPoint).div(totalAllocPoint)
      const rewardBalance = (await fateToken.balanceOf(this.bob.address)).sub(fateWalletBalanceBefore)
      expect(rewardBalance).to.be.equal(unlockedRewards.sub(unlockedRewards.mul(expectedRewardFee).div(10000)))

      const pointsPerSecond = ethers.BigNumber.from('40000000000000000')

      const expectedPointsAfterWithdrawal = withdrawalTimestamp.sub(depositTimestamp).mul(pointsPerSecond)
      expect(await fateRewardControllerV3.allUserPoints(this.bob.address)).to.be.equal(expectedPointsAfterWithdrawal)

      await time.advanceTime(1234)
      const latestTimestamp = await time.latestTimestamp()
      const expectedPointsAfterTime = latestTimestamp.sub(depositTimestamp).mul(pointsPerSecond)
      expect(await fateRewardControllerV3.allUserPoints(this.bob.address)).to.be.equal(expectedPointsAfterTime)

      await fateRewardControllerV3.connect(this.bob).withdrawAll()
      const timestampAfterWithdrawAll = await time.latestTimestamp()
      const expectedPointsAfterWithdrawAll = timestampAfterWithdrawAll.sub(depositTimestamp).mul(pointsPerSecond)
      // points don't go up after a user has exited positions
      await time.advanceTime(1234)
      expect(await fateRewardControllerV3.allUserPoints(this.bob.address)).to.be.equal(expectedPointsAfterWithdrawAll)
    }
  })
})
