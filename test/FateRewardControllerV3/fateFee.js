const { ethers } = require('hardhat')
const { expect, use} = require('chai')
const { solidity } = require("ethereum-waffle")
const { deployContract } = require("../shared/fixtures")
const { expandDecimals } = require("../shared/utilities")
const { advanceBlock, advanceBlockTo, advanceBlockFor, duration } = require('../utilities/time')
const { BigNumber } = require('ethers')

use(solidity)

describe('FateRewardControllerV3.Fate fees', () => {
    const startBlock = 10
    let lpToken;
    let fateToken;
    let rewardSchedule;
    let fateRewardControllerV2;
    let fateRewardControllerV3;
    let mockLpTokenFactory;

    const doDeposit = async (depositor, depositAmount) => {
        const beforeBalance = await lpToken.balanceOf(depositor.address)
        await fateRewardControllerV3.connect(depositor).deposit(0, depositAmount)
        const afterBalance = await lpToken.balanceOf(depositor.address)
        expect(beforeBalance.sub(afterBalance)).to.be.equal(depositAmount)
    }

    const doSomeDeposits = async () => {
        await doDeposit(this.bob, expandDecimals(10))
        await advanceBlock()
        await advanceBlock()
        await doDeposit(this.dev, expandDecimals(10))
        await advanceBlock()
        await advanceBlock()
    }

    const getPendingUnlockedFate = async (isNextBlock) => {
        const bobInfo = await fateRewardControllerV3.userInfo(0, this.bob.address)
        const pool = await fateRewardControllerV3.poolInfo(0)
        const latestBlockNumber = await ethers.provider.getBlockNumber()
        const lpBalance = await lpToken.balanceOf(fateRewardControllerV3.address)

        const getFatePerBlock = await rewardSchedule.getFatePerBlock(
            startBlock + 1,
            pool.lastRewardBlock,
            isNextBlock ? latestBlockNumber + 1 : latestBlockNumber
        )
        const accumulatedFatePerShare = await pool.accumulatedFatePerShare.add(getFatePerBlock[1].mul(BigNumber.from(1e12.toString())).div(lpBalance))
        const actualPendingUnlockedFate = await bobInfo.amount.mul(accumulatedFatePerShare).div(1e12).sub(bobInfo.rewardDebt)
        return actualPendingUnlockedFate
    }

    const getPendingLockedFate = async (isNextBlock) => {
        const bobInfo = await fateRewardControllerV3._getUserInfo(0, this.bob.address)
        const pool = await fateRewardControllerV3.poolInfo(0)
        const latestBlockNumber = await ethers.provider.getBlockNumber()
        const lpBalance = await lpToken.balanceOf(fateRewardControllerV3.address)

        const getFatePerBlock = await rewardSchedule.getFatePerBlock(
            startBlock + 1,
            pool.lastRewardBlock,
            isNextBlock ? latestBlockNumber + 1 : latestBlockNumber
        )
        const accumulatedLockedFatePerShare = await pool.accumulatedLockedFatePerShare.add(getFatePerBlock[0].mul(BigNumber.from(1e12.toString())).div(lpBalance))
        const lockedReward = await bobInfo.amount.mul(accumulatedLockedFatePerShare).div(BigNumber.from(1e12.toString())).sub(bobInfo.lockedRewardDebt)
        const getLockedRewardsFeePercent = await fateRewardControllerV3.getLockedRewardsFeePercent(0, this.bob.address)
        const actualPendingLockedFate = await lockedReward.sub(lockedReward.mul(getLockedRewardsFeePercent).div(BigNumber.from(1e18.toString())))
        return actualPendingLockedFate
    }

    const claimRewardAmount = async () => {
        const beforeBalance = await fateToken.balanceOf(this.bob.address)
        await fateRewardControllerV3.connect(this.bob).claimReward(0)
        const afterBalance = await fateToken.balanceOf(this.bob.address)
        return afterBalance.sub(beforeBalance)
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
            fateToken = await deployContract('FateToken', [this.alice.address, expandDecimals(20000000)])
            await fateToken.connect(this.alice).transfer(this.bob.address, expandDecimals(100))
            await fateToken.connect(this.alice).transfer(this.dev.address, expandDecimals(100))
            lpToken = await deployContract('ERC20Mock', ['lp', 'LP', expandDecimals(1000)])
            rewardSchedule = await deployContract('RewardScheduleV3', [])
            await advanceBlockTo(startBlock)
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
                this.feeTo.address]
            )

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
            await fateToken.transfer(this.vault.address, expandDecimals(15000000))
            await fateToken.connect(this.vault).approve(
                fateRewardControllerV3.address,
                await fateToken.balanceOf(this.vault.address) // expandDecimals(100)
            )
        } catch (e) {
            console.log('INHO')
            console.log(e)
        }
    })

    describe('PendingUnlockedFate & PendingLokedFate', async () => {
        it('PendingUnlockedFate', async () => {
            // assert whether pendingUnlockedFate is as expected or not when no deposit
            expect(await fateRewardControllerV3.pendingUnlockedFate(0, this.bob.address))
                .to.be.eq(await getPendingUnlockedFate(false))

            // assert whether pendingUnlockedFate is as expected or not after first deposit
            await doSomeDeposits()
            expect(await fateRewardControllerV3.pendingUnlockedFate(0, this.bob.address))
                .to.be.eq(await getPendingUnlockedFate(false))

            // assert whether pendingUnlockedFate is as expected or not after 1 hour
            await doSomeDeposits()
            await advanceBlockFor(duration.hours(1))
            expect(await fateRewardControllerV3.pendingUnlockedFate(0, this.bob.address))
                .to.be.eq(await getPendingUnlockedFate(false))

            // assert whether pendingUnlockedFate is as expected or not after third deposit and a day
            await doSomeDeposits()
            await advanceBlockFor(duration.days(1))
            expect(await fateRewardControllerV3.pendingUnlockedFate(0, this.bob.address))
                .to.be.eq(await getPendingUnlockedFate(false))
        })

        it('ClaimRewards', async () => {
            // assert whether the reward token's balance is as expected or not 
            // after claiming when no deposit
            expect(await claimRewardAmount()).to.be.eq(await getPendingUnlockedFate(true))

            // assert whether the reward token's balance is as expected or not 
            // after claiming when first deposit
            await doSomeDeposits()
            expect(await getPendingUnlockedFate(true)).to.be.eq(await claimRewardAmount())

            // assert whether the reward token's balance is as expected or not 
            // after claiming when some deposit and 1 hour has passed
            await doSomeDeposits()
            await advanceBlockFor(duration.hours(1))
            expect(await getPendingUnlockedFate(true)).to.be.eq(await claimRewardAmount())

            // assert whether the reward token's balance is as expected or not 
            // after claiming when third deposit and a day has passed
            await doSomeDeposits()
            await advanceBlockFor(duration.days(1))
            expect(await getPendingUnlockedFate(true)).to.be.eq(await claimRewardAmount())
        })

        it('PendingLokedFate', async () => {
            // assert whether pendingLockedFate is as expected or not when no deposit
            expect(await fateRewardControllerV3.pendingLockedFate(0, this.bob.address))
                .to.be.eq(await getPendingLockedFate(false))

            // assert whether pendingUnlockedFate is as expected or not after first deposit
            await doSomeDeposits()
            expect(await fateRewardControllerV3.pendingLockedFate(0, this.bob.address))
                .to.be.eq(await getPendingLockedFate(false))

            // assert whether pendingUnlockedFate is as expected or not after some deposit and 1 hour
            await doSomeDeposits()
            await advanceBlockFor(duration.hours(1))
            expect(await fateRewardControllerV3.pendingLockedFate(0, this.bob.address))
                .to.be.eq(await getPendingLockedFate(false))

            // assert whether pendingLockedFate is as expected or not after third deposit and a day
            await doSomeDeposits()
            await advanceBlockFor(duration.days(1))
            expect(await fateRewardControllerV3.pendingLockedFate(0, this.bob.address))
                .to.be.eq(await getPendingLockedFate(false))
        })

        it('UserMembershipInfo', async () => {
            // assert whether userMembershipInfo is as expected or not when no deposit
            let userMembershipInfo = await fateRewardControllerV3.userMembershipInfo(0, this.bob.address)
            expect(userMembershipInfo[0]).to.be.eq(0)
            expect(userMembershipInfo[1]).to.be.eq(0)

            // assert whether userMembershipInfo is as expected or not after first deposit
            await fateRewardControllerV3.connect(this.bob).deposit(0, expandDecimals(10))
            let blockNumber = await ethers.provider.getBlockNumber()
            userMembershipInfo = await fateRewardControllerV3.userMembershipInfo(0, this.bob.address)
            expect(userMembershipInfo[0]).to.be.eq(blockNumber) // firstDepositBlock
            expect(userMembershipInfo[1]).to.be.eq(blockNumber) // lastWithdrawBlock

            // assert whether userMembershipInfo is as expected or not after withdrawAll
            await fateRewardControllerV3.connect(this.bob).withdrawAll()
            blockNumber = await ethers.provider.getBlockNumber()
            let lastWithdrawBlock = blockNumber
            userMembershipInfo = await fateRewardControllerV3.userMembershipInfo(0, this.bob.address)
            expect(userMembershipInfo[0]).to.be.eq(0)
            expect(userMembershipInfo[1]).to.be.eq(blockNumber)

            // assert whether userMembershipInfo is as expected or not after withdrawAll and deposit
            await fateRewardControllerV3.connect(this.bob).deposit(0, expandDecimals(10))
            blockNumber = await ethers.provider.getBlockNumber()
            let firstDepositBlock = blockNumber
            userMembershipInfo = await fateRewardControllerV3.userMembershipInfo(0, this.bob.address)
            expect(userMembershipInfo[0]).to.be.eq(blockNumber)
            expect(userMembershipInfo[1]).to.be.eq(lastWithdrawBlock)

            // assert whether userMembershipInfo is as expected or not after deposit and some withdraw
            await fateRewardControllerV3.connect(this.bob).withdraw(0, expandDecimals(5))
            blockNumber = await ethers.provider.getBlockNumber()
            userMembershipInfo = await fateRewardControllerV3.userMembershipInfo(0, this.bob.address)
            expect(userMembershipInfo[0]).to.be.eq(firstDepositBlock)
            expect(userMembershipInfo[1]).to.be.eq(blockNumber)
        })

        it('LP balance', async () => {
            // assert whether user's wallet LP balances is as expected or not after first deposit
            let beforeLPBalance = await lpToken.balanceOf(this.bob.address)
            await fateRewardControllerV3.connect(this.bob).deposit(0, expandDecimals(10))
            let afterLPBalance = await lpToken.balanceOf(this.bob.address)
            expect(beforeLPBalance.sub(afterLPBalance)).to.be.equal(expandDecimals(10))

            // assert whether user's wallet LP balances is as expected or not after second deposit
            beforeLPBalance = await lpToken.balanceOf(this.bob.address)
            await fateRewardControllerV3.connect(this.bob).deposit(0, expandDecimals(10))
            afterLPBalance = await lpToken.balanceOf(this.bob.address)
            expect(beforeLPBalance.sub(afterLPBalance)).to.be.equal(expandDecimals(10))

            // assert whether user's wallet LP balances is as expected or not after withdrawAll
            let beforeFeeToBalance = await lpToken.balanceOf(this.feeTo.address)
            beforeLPBalance = await lpToken.balanceOf(this.bob.address)
            await fateRewardControllerV3.connect(this.bob).withdrawAll()
            afterLPBalance = await lpToken.balanceOf(this.bob.address)
            let withdrawalAmount = expandDecimals(20)
            // LP Withdraw Fee Percent is 88% during 30 blocks after deposit
            let amountSentTo_fateFeeTo = await withdrawalAmount.mul(8800).div(10000)
            let afterFeeToBalance = await lpToken.balanceOf(this.feeTo.address)
            expect(afterLPBalance.sub(beforeLPBalance)).to.be.equal(withdrawalAmount.sub(amountSentTo_fateFeeTo))
            expect(afterFeeToBalance.sub(beforeFeeToBalance)).to.be.equal(amountSentTo_fateFeeTo)

            // assert whether userMembershipInfo is as expected or not after deposit and some withdraw
            beforeFeeToBalance = await lpToken.balanceOf(this.feeTo.address)
            await fateRewardControllerV3.connect(this.bob).deposit(0, expandDecimals(10))
            beforeLPBalance = await lpToken.balanceOf(this.bob.address)
            await fateRewardControllerV3.connect(this.bob).withdraw(0, expandDecimals(5))
            afterLPBalance = await lpToken.balanceOf(this.bob.address)
            withdrawalAmount = expandDecimals(5)
            // LP Withdraw Fee Percent is 88% during 30 blocks after deposit
            amountSentTo_fateFeeTo = await withdrawalAmount.mul(8800).div(10000)
            afterFeeToBalance = await lpToken.balanceOf(this.feeTo.address)
            expect(afterLPBalance.sub(beforeLPBalance)).to.be.equal(withdrawalAmount.sub(amountSentTo_fateFeeTo))
            expect(afterFeeToBalance.sub(beforeFeeToBalance)).to.be.equal(amountSentTo_fateFeeTo)

            // assert whether userMembershipInfo is as expected or not after deposit and some withdraw
            beforeFeeToBalance = await lpToken.balanceOf(this.feeTo.address)
            await fateRewardControllerV3.connect(this.bob).deposit(0, expandDecimals(10))
            await advanceBlockFor(duration.minutes(1))
            beforeLPBalance = await lpToken.balanceOf(this.bob.address)
            await fateRewardControllerV3.connect(this.bob).withdraw(0, expandDecimals(5))
            afterLPBalance = await lpToken.balanceOf(this.bob.address)
            withdrawalAmount = expandDecimals(5)
            // LP Withdraw Fee Percent is 72% after deposit and 1 min
            amountSentTo_fateFeeTo = await withdrawalAmount.mul(7200).div(10000)
            afterFeeToBalance = await lpToken.balanceOf(this.feeTo.address)
            expect(afterLPBalance.sub(beforeLPBalance)).to.be.equal(withdrawalAmount.sub(amountSentTo_fateFeeTo))
            expect(afterFeeToBalance.sub(beforeFeeToBalance)).to.be.equal(amountSentTo_fateFeeTo)

            // assert whether userMembershipInfo is as expected or not after deposit and some withdraw
            beforeFeeToBalance = await lpToken.balanceOf(this.feeTo.address)
            await fateRewardControllerV3.connect(this.bob).deposit(0, expandDecimals(10))
            await advanceBlockFor(duration.hours(2))
            beforeLPBalance = await lpToken.balanceOf(this.bob.address)
            await fateRewardControllerV3.connect(this.bob).withdraw(0, expandDecimals(5))
            afterLPBalance = await lpToken.balanceOf(this.bob.address)
            withdrawalAmount = expandDecimals(5)
            // LP Withdraw Fee Percent is 18% after deposit and 2 hours
            amountSentTo_fateFeeTo = await withdrawalAmount.mul(1800).div(10000)
            afterFeeToBalance = await lpToken.balanceOf(this.feeTo.address)
            expect(afterLPBalance.sub(beforeLPBalance)).to.be.equal(withdrawalAmount.sub(amountSentTo_fateFeeTo))
            expect(afterFeeToBalance.sub(beforeFeeToBalance)).to.be.equal(amountSentTo_fateFeeTo)
        })
    })
})
