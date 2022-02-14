const { ethers } = require('hardhat')
const { expect, use} = require('chai')
const { solidity } = require("ethereum-waffle")
const { deployContract } = require("../shared/fixtures")
const { expandDecimals } = require("../shared/utilities")
const { advanceBlockTo } = require('../utilities/time')

use(solidity)

describe('FateRewardControllerV3.setLockedRewardsData', () => {
    const startBlock = 10
    let lpToken;
    let fateToken;
    let rewardSchedule;
    let fateRewardControllerV2;
    let fateRewardControllerV3;
    let mockLpTokenFactory;

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

    describe('setLockedRewardsData', async () => {
        it('reverted cases:', async () => {
            // when trying to set with not-owner
            await expect(
                fateRewardControllerV3.connect(this.dev).setLockedRewardsData(
                    [30, 60],
                    [expandDecimals(1), expandDecimals(98, 16)]
                )
            ).to.be.revertedWith('Ownable: caller is not the owner')

            // when trying with invalid input data
            await expect(
                fateRewardControllerV3.setLockedRewardsData([],[])
            ).to.be.revertedWith('setLockedRewardsData: invalid input data')

            await expect(
                fateRewardControllerV3.setLockedRewardsData([30, 60],[])
            ).to.be.revertedWith('setLockedRewardsData: invalid input data')
        })

        it('success cases:', async () => {
            await fateRewardControllerV3.setLockedRewardsData(
                [10, 20],[expandDecimals(1), expandDecimals(98, 16)]
            )
            const lockedRewardsPeriodBlock = await fateRewardControllerV3.lockedRewardsPeriodBlocks(0)
            expect(lockedRewardsPeriodBlock).to.be.equal(10)
            const lockedRewardsFeePercent = await fateRewardControllerV3.lockedRewardsFeePercents(0)
            expect(lockedRewardsFeePercent).to.be.equal(expandDecimals(1))
        })
    })
})
