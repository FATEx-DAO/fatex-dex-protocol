const { ethers } = require('hardhat')
const { expect, use} = require('chai')
const { solidity } = require("ethereum-waffle")
const { deployContract } = require("../shared/fixtures")
const { expandDecimals } = require("../shared/utilities")
const { advanceBlock, advanceBlockTo, advanceBlockFor, duration } = require('../utilities/time')
const { BigNumber } = require('ethers')

use(solidity)

describe('FateRewardControllerV3.MembershipReward and Withdraw', () => {
    const epoch_period_blocks = 30 * 60 * 24 * 7 * 8 // 8 weeks
    const points_per_block = BigNumber.from(0.08e18.toString())
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

    describe('MembershipReward & WithdrawFees', async () => {
        it('MembershipReward', async () => {
            // do some deposit actions
            await doSomeDeposits()

            const bobUserPoints = await fateRewardControllerV3.userPoints(0, this.bob.address)
            const devUserPoints = await fateRewardControllerV3.userPoints(0, this.dev.address)
            const vaultUserPoints = await fateRewardControllerV3.userPoints(0, this.vault.address)

            expect(bobUserPoints).to.above(0)
            expect(devUserPoints).to.above(0)
            expect(bobUserPoints).to.above(devUserPoints)
            expect(vaultUserPoints).to.be.equal(0)
        })

        // TODO repeat these tests here that assert the two different kinds of fee percentages being applied properly
        //  for different deposit times:
        //  - lockedRewardsFeePercents[0] == 10000 && lpWithdrawFeePercent[0] == 10000
        //  - lockedRewardsFeePercents[1] == 9800 && lpWithdrawFeePercent[1] == 8800
        //  - lockedRewardsFeePercents[length - 2] == 180 && lpWithdrawFeePercent[length - 2] == 18
        //  - lockedRewardsFeePercents[length - 1] == 80 && lpWithdrawFeePercent[length - 1] == 8
        //  Make sure the tests are dynamic. Don't hardcode lockedRewardsFeePercents[0] as `10000`. Instead, call the
        //  contract fateRewardControllerV3.lockedRewardsFeePercents(0) and initialize it that way in case the fees
        //  change.
        it('Withdraw', async () => {
            await doSomeDeposits()

            const withdrawAmount = expandDecimals(1)
            const bobBeforeLPAmount = await lpToken.balanceOf(this.bob.address)

            // when withdraw after 5 blocks, lockedRewardFee: 100%, lpWithdrawFee: 88%
            await fateRewardControllerV3.connect(this.bob).withdraw(0, withdrawAmount)
            const bobAfterLPAmount = await lpToken.balanceOf(this.bob.address)
            const receivedAmount = bobAfterLPAmount.sub(bobBeforeLPAmount)

            // check received amount after withdraw: withdrawAmount * (100 - lpWithdrawFee)
            expect(receivedAmount).to.be.eq(withdrawAmount.mul(100 - 88).div(100))

            // check fee is sent to fateFeeTo
            expect(await fateRewardControllerV3.fateFeeTo()).to.be.equal(this.feeTo.address)
            const feeToBalance = await lpToken.balanceOf(this.feeTo.address)
            expect(feeToBalance).to.be.eq(withdrawAmount.mul(88).div(100))

            // userLockedRewards should be zero since lockedRewardFee is 100%
            const bobLockedRewards = await fateRewardControllerV3.userLockedRewards(0, this.bob.address)
            expect(bobLockedRewards).to.be.equal(0)

            // withdraw all dev
            await fateRewardControllerV3.connect(this.dev).withdraw(
                0, expandDecimals(10)
            )
            const beforeDevPoints = await fateRewardControllerV3.userPoints(
                0,
                this.dev.address
            )
            await advanceBlock()
            let afterDevPoints = await fateRewardControllerV3.userPoints(
                0,
                this.dev.address
            )
            expect(beforeDevPoints).to.be.equal(afterDevPoints)

            // deposit again
            await doDeposit(this.dev, expandDecimals(9))
            await advanceBlock()
            afterDevPoints = await fateRewardControllerV3.userPoints(
                0,
                this.dev.address
            )
            expect(afterDevPoints).to.above(beforeDevPoints)

            // withdrawAll
            await doDeposit(this.bob, expandDecimals(10))
            await fateRewardControllerV3.connect(this.bob).withdrawAll()
            const { amount: bobAfterInfo } = await fateRewardControllerV3.userInfo(
                0,
                this.bob.address
            )
            expect(bobAfterInfo).to.be.equal(expandDecimals(0))

            // emergencyWithdraw
            await doDeposit(this.dev, expandDecimals(10))
            await fateRewardControllerV3.connect(this.dev).emergencyWithdraw(0)
            const { amount: devAfterInfo } = await fateRewardControllerV3.userInfo(
                0,
                this.dev.address
            )
            expect(devAfterInfo).to.be.equal(expandDecimals(0))
        })
    })

    describe('TrackedPoints', async () => {
        it('TrackedPoints', async () => {
            let expectTrackedPoints = BigNumber.from(0);
            expect(await fateRewardControllerV3.trackedPoints(0, this.bob.address)).to.be.eq(expectTrackedPoints)

            // withdrawAll after some deposits (5 blocks)
            await doSomeDeposits()
            await fateRewardControllerV3.connect(this.bob).withdrawAll()
            expectTrackedPoints = expectTrackedPoints.add(points_per_block.mul(5))
            expect(await fateRewardControllerV3.trackedPoints(0, this.bob.address)).to.be.eq(expectTrackedPoints)

            // withdrawAll after some deposits and 1 min
            await doSomeDeposits()
            await advanceBlockFor(duration.minutes(1))
            await fateRewardControllerV3.connect(this.bob).withdrawAll()
            expectTrackedPoints = expectTrackedPoints.add(points_per_block.mul(65))
            expect(await fateRewardControllerV3.trackedPoints(0, this.bob.address)).to.be.eq(expectTrackedPoints)

            // withdrawAll after some deposits and 1 hour
            await doSomeDeposits()
            await advanceBlockFor(duration.hours(1))
            await fateRewardControllerV3.connect(this.bob).withdrawAll()
            expectTrackedPoints = expectTrackedPoints.add(points_per_block.mul(3605))
            expect(await fateRewardControllerV3.trackedPoints(0, this.bob.address)).to.be.eq(expectTrackedPoints)

            // withdrawAll after some deposits and 1 day
            await doSomeDeposits()
            await advanceBlockFor(duration.days(1))
            await fateRewardControllerV3.connect(this.bob).withdrawAll()
            expectTrackedPoints = expectTrackedPoints.add(points_per_block.mul(86405))
            expect(await fateRewardControllerV3.trackedPoints(0, this.bob.address)).to.be.eq(expectTrackedPoints)
        })
    })
})
