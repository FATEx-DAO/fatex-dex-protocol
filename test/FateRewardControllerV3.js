const { ethers } = require('hardhat')
const { expect } = require('chai')
const { deployContract } = require("./shared/fixtures")
const { expandDecimals } = require("./shared/utilities")
const { advanceBlock, advanceBlockTo } = require('./utilities/time')

// yarn test test/FateRewardControllerV3.test.js
describe('FateRewardControllerV3', () => {
    const epoch_period_blocks = 30 * 60 * 24 * 7 * 8 // 8 weeks
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

    const doSomeDeposists = async () => {
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

    describe('MembershipReward & WithdrawFees', async () => {
        it('MembershipReward', async () => {
            // do some deposit actions
            await doSomeDeposists()

            const bobUserPoints = await fateRewardControllerV3.userPoints(0, this.bob.address)
            const devUserPoints = await fateRewardControllerV3.userPoints(0, this.dev.address)
            const vaultUserPoints = await fateRewardControllerV3.userPoints(0, this.vault.address)

            expect(bobUserPoints).to.above(0)
            expect(devUserPoints).to.above(0)
            expect(bobUserPoints).to.above(devUserPoints)
            expect(vaultUserPoints).to.be.equal(0)
        })

        it('Withdraw', async () => {
            await doSomeDeposists()

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

    describe('claimReward', async () => {
        it('claimReward', async () => {
            const bobInfo = await fateRewardControllerV3.userInfo(0, this.bob.address)
            const pool = await fateRewardControllerV3.poolInfo(0)
            const pendingUnlocked = bobInfo.amount
                .mul(pool.accumulatedFatePerShare)
                .div(1e12)
                .sub(bobInfo.rewardDebt);

            await expect(fateRewardControllerV3.connect(this.bob).claimReward(0))
                .to.emit(fateRewardControllerV3, 'ClaimRewards')
                .withArgs(this.bob.address, 0, pendingUnlocked)
        })
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
        }),

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

    describe('excluded Addresses', async () => {
        it('reverted cases:', async() => {
            // when trying to set with not-owner
            await expect(
                fateRewardControllerV3.connect(this.dev).setExcludedAddresses(
                    [this.alice.address],
                    [true]
                )
            ).to.be.revertedWith('Ownable: caller is not the owner')

            // when trying with invalid input data
            await expect(
                fateRewardControllerV3.setExcludedAddresses(
                    [this.alice.address],
                    []
                )
            ).to.be.revertedWith('setExcludedAddresses: invalid data')
        })

        it('success cases:', async() => {
            const beforeStatus = await fateRewardControllerV3.isExcludedAddress(
                this.dev.address
            )
            expect(beforeStatus).to.be.false
            await fateRewardControllerV3.setExcludedAddresses(
                [this.dev.address],
                [true]
            )
            const afterStatus = await fateRewardControllerV3.isExcludedAddress(
                this.dev.address
            )
            expect(afterStatus).to.be.true
        })
    })

    describe('setFateFeeTo', async () => {
        it('reverted cases:', async () => {
            // when trying to set with not-owner
            await expect(
                fateRewardControllerV3.connect(this.dev).setFateFeeTo(this.bob.address)
            ).to.be.revertedWith('Ownable: caller is not the owner')
        }),

            it('success cases:', async () => {
                await fateRewardControllerV3.setFateFeeTo(this.bob.address)
                expect(await fateRewardControllerV3.fateFeeTo()).to.be.equal(this.bob.address)
            })
    })

    describe('addLP', async () => {
        it('reverted cases:', async () => {
            const testLP1 = await deployContract('ERC20Mock', ['testlp1', 'TestLP1', expandDecimals(1000)])
            const testLP2 = await deployContract('ERC20Mock', ['testlp2', 'TestLP2', expandDecimals(1000)])
            const testLP3 = await deployContract('ERC20Mock', ['testlp3', 'TestLP3', expandDecimals(1000)])

            // when trying to set with not-owner
            await expect(
                fateRewardControllerV3.connect(this.dev).add(1, testLP1.address, true)
            ).to.be.revertedWith('Ownable: caller is not the owner')

            await fateRewardControllerV3.add(1, testLP1.address, true)
            // when tyring to add LP token already added
            await expect(
                fateRewardControllerV3.add(1, testLP1.address, true)
            ).to.be.revertedWith('add: LP token already added')

              // // when tyring to add invalid LP token
              // await expect(
              //   fateRewardControllerV3.add(1, testLP1.address, true)
              // ).to.be.revertedWith('add: invalid LP token')

            await expect(
                fateRewardControllerV3.connect(this.dev).addMany([testLP1.address, testLP2.address])
            ).to.be.revertedWith('Ownable: caller is not the owner')
        }),

            it('success cases:', async () => {
                const testLP1 = await deployContract('ERC20Mock', ['testlp1', 'TestLP1', expandDecimals(1000)])
                await testLP1.deployed()
                const testLP2 = await deployContract('ERC20Mock', ['testlp2', 'TestLP2', expandDecimals(1000)])
                await testLP2.deployed()
                const testLP3 = await deployContract('ERC20Mock', ['testlp3', 'TestLP3', expandDecimals(1000)])
                await testLP3.deployed()

                let length = await fateRewardControllerV3.poolLength()
                await expect(fateRewardControllerV3.add(1, testLP1.address, true))
                    .to.emit(fateRewardControllerV3, 'PoolAdded')
                    .withArgs(length, testLP1.address, 1)

                await fateRewardControllerV3.addMany([testLP2.address, testLP3.address])
                length = await fateRewardControllerV3.poolLength()
                const lastLP1 = await fateRewardControllerV3.poolInfo(length - 1)
                const lastLP2 = await fateRewardControllerV3.poolInfo(length - 2)
                expect(lastLP2.lpToken).to.be.equal(testLP2.address)
                expect(lastLP1.lpToken).to.be.equal(testLP3.address)

            })
    })

    describe('setPool', async () => {
        it('reverted cases:', async () => {
            // when trying to set with not-owner
            await expect(
                fateRewardControllerV3.connect(this.dev).set(0, 2, true)
            ).to.be.revertedWith('Ownable: caller is not the owner')

            const testLP = await deployContract('ERC20Mock', ['testlp', 'TestLP', expandDecimals(1000)])
            await testLP.deployed()
            await fateRewardControllerV3.add(1, testLP.address, true)

            await expect(
                fateRewardControllerV3.connect(this.dev).setMany([0, 1], [2, 3])
            ).to.be.revertedWith('Ownable: caller is not the owner')

            await expect(
                fateRewardControllerV3.connect(this.dev).setManyWith2dArray([[0, 2], [1, 3]])
            ).to.be.revertedWith('Ownable: caller is not the owner')

        }),
        it('success cases:', async () => {
                await expect(fateRewardControllerV3.set(0, 2, true))
                    .to.emit(fateRewardControllerV3, 'PoolAllocPointSet')
                    .withArgs(0, 2)

                const testLP = await deployContract('ERC20Mock', ['testlp', 'TestLP', expandDecimals(1000)])
                await testLP.deployed()
                await fateRewardControllerV3.add(1, testLP.address, true)

                await fateRewardControllerV3.setMany([0, 1], [2, 3])
                let LP1 = await fateRewardControllerV3.poolInfo(0)
                let LP2 = await fateRewardControllerV3.poolInfo(1)
                expect(LP1.allocPoint.toString()).to.be.equal('2')
                expect(LP2.allocPoint.toString()).to.be.equal('3')

                await fateRewardControllerV3.setManyWith2dArray([[0, 3], [1, 4]])
                LP1 = await fateRewardControllerV3.poolInfo(0)
                LP2 = await fateRewardControllerV3.poolInfo(1)
                expect(LP1.allocPoint.toString()).to.be.equal('3')
                expect(LP2.allocPoint.toString()).to.be.equal('4')
            })
    })

    describe('setMigrator', async () => {
        it('reverted cases:', async () => {
            // when trying to set with not-owner
            await expect(
                fateRewardControllerV3.connect(this.dev).setMigrator(this.bob.address)
            ).to.be.revertedWith('Ownable: caller is not the owner')
        }),

            it('success cases:', async () => {
                await expect(fateRewardControllerV3.setMigrator(this.bob.address))
                    .to.emit(fateRewardControllerV3, 'MigratorSet')
                    .withArgs(this.bob.address)
            })
    })

    describe('migrate', async () => {
        it('success cases:', async () => {
            // const testLP1 = await deployContract('ERC20Mock', ['testlp1', 'TestLP1', expandDecimals(1000))
            // await testLP1.deployed()
            // const length = await fateRewardControllerV3.poolLength()
            // await fateRewardControllerV3.setMigrator(this.bob.address)
            // // await fateRewardControllerV3.connect(this.bob).migrate(testLP1.address)
            // const lastLP1 = await fateRewardControllerV3.poolInfo(length)
            // expect(lastLP1.lpToken).to.be.equal(testLP1.address)
        })
    })

    describe('setEmissionSchedule', async () => {
        it('reverted cases:', async () => {
            // when trying to set with not-owner
            await expect(
                fateRewardControllerV3.connect(this.dev).setEmissionSchedule(rewardSchedule.address)
            ).to.be.revertedWith('Ownable: caller is not the owner')
        }),

            it('success cases:', async () => {
                await expect(fateRewardControllerV3.setEmissionSchedule(rewardSchedule.address))
                    .to.emit(fateRewardControllerV3, 'EmissionScheduleSet')
                    .withArgs(rewardSchedule.address)
            })
    })

    describe('setVault', async () => {
        it('reverted cases:', async () => {
            // when trying to set with not-owner
            await expect(
                fateRewardControllerV3.connect(this.dev).setVault(this.vault.address)
            ).to.be.revertedWith('Ownable: caller is not the owner')
        }),

            it('success cases:', async () => {
                await expect(fateRewardControllerV3.setVault(this.vault.address))
                    .to.emit(fateRewardControllerV3, 'VaultSet')
                    .withArgs(this.vault.address)
            })
    })
})
