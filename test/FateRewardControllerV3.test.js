const { ethers, network } = require('hardhat')
const { expect } = require('chai')

const { getBigNumber } = require('./utilities')
const { advanceBlock, advanceBlockTo } = require('./utilities/time')
const { BigNumber } = require('@ethersproject/bignumber')

// yarn test test/FateRewardControllerV3.test.js
describe('FateRewardControllerV3', () => {
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
      this.feeTo = this.signers[4]

      this.LP = await ethers.getContractFactory('ERC20Mock')
      this.FateToken = await ethers.getContractFactory('FateToken')
      this.FateRewardControllerV2 = await ethers.getContractFactory('FateRewardController')
      this.FateRewardControllerV3 = await ethers.getContractFactory('FateRewardControllerV3')
      this.RewardSchedule = await ethers.getContractFactory('RewardScheduleV3')
      this.MockLpTokenFactory = await ethers.getContractFactory('MockLpTokenFactory')      
    })

    beforeEach(async () => {
      try {
        this.fateToken = await this.FateToken.deploy(this.alice.address, getBigNumber(1000))
        await this.fateToken.deployed()
        await this.fateToken.connect(this.alice).transfer(this.bob.address, getBigNumber(100))
        await this.fateToken.connect(this.alice).transfer(this.dev.address, getBigNumber(100))
        this.lp = await this.LP.deploy('lp', 'LP', getBigNumber(1000))
        await this.lp.deployed()
        this.rewardSchedule = await this.RewardSchedule.deploy(
          startBlock
        )

        await this.rewardSchedule.deployed()
        await advanceBlockTo(startBlock)
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
          this.feeTo.address
        )
        await this.fateRewardControllerV3.deployed()
  
        // add pool
        await this.fateRewardControllerV3.add(1, this.lp.address, true)
  
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
      } catch (e) {
        console.log('INHO')
        console.log(e)
      }      
    })

    describe('MembershipReward & WithdrawFees', async () => {
      it('MembershipReward', async () => {
        // do some deposit actions
        await doSomeDeposists()

        const bobUserPoints = await this.fateRewardControllerV3.userPoints(0, this.bob.address)
        const devUserPoints = await this.fateRewardControllerV3.userPoints(0, this.dev.address)
        const vaultUserPoints = await this.fateRewardControllerV3.userPoints(0, this.vault.address)

        expect(bobUserPoints).to.above(0)
        expect(devUserPoints).to.above(0)
        expect(bobUserPoints).to.above(devUserPoints)
        expect(vaultUserPoints).to.be.equal(0)
      })

      it('Withdraw', async () => {
        await doSomeDeposists()

        const withdrawAmount = getBigNumber(1)
        const bobBeforeLPAmount = await this.lp.balanceOf(this.bob.address)

        // when withdraw after 5 blocks, lockedRewardFee: 100%, lpWithdrawFee: 88%
        await this.fateRewardControllerV3.connect(this.bob).withdraw(0, withdrawAmount)
        const bobAfterLPAmount = await this.lp.balanceOf(this.bob.address)
        const receivedAmount = bobAfterLPAmount.sub(bobBeforeLPAmount)

        // check received amount after withdraw: withdrawAmount * (100 - lpWithdrawFee)
        expect(receivedAmount).to.be.equal(withdrawAmount.mul(100 - 88).div(100))

        // check fee is sent to fateFeeTo
        expect(await this.fateRewardControllerV3.fateFeeTo()).to.be.equal(this.feeTo.address)
        const feeToBalance = await this.lp.balanceOf(this.feeTo.address)
        expect(feeToBalance).to.be.eq(withdrawAmount.mul(88).div(100))

        // userLockedRewards should be zero since lockedRewardFee is 100%
        const bobLockedRewards = await this.fateRewardControllerV3.userLockedRewards(0, this.bob.address)
        expect(bobLockedRewards).to.be.equal(0)

        // withdraw all dev
        await this.fateRewardControllerV3.connect(this.dev).withdraw(
          0, getBigNumber(10)
        )
        const beforeDevPoints = await this.fateRewardControllerV3.userPoints(
          0,
          this.dev.address
        )
        await advanceBlock()
        let afterDevPoints = await this.fateRewardControllerV3.userPoints(
          0,
          this.dev.address
        )
        expect(beforeDevPoints).to.be.equal(afterDevPoints)

        // deposit again
        await doDeposit(this.dev, getBigNumber(9))
        await advanceBlock()
        afterDevPoints = await this.fateRewardControllerV3.userPoints(
          0,
          this.dev.address
        )
        expect(afterDevPoints).to.above(beforeDevPoints)

        // withdrawAll
        await doDeposit(this.bob, getBigNumber(10))
        await this.fateRewardControllerV3.connect(this.bob).withdrawAll()
        const { amount: bobAfterInfo } = await this.fateRewardControllerV3.userInfo(
          0,
          this.bob.address
        )
        expect(bobAfterInfo).to.be.equal(getBigNumber(0))

        // emergencyWithdraw
        await doDeposit(this.dev, getBigNumber(10))
        await this.fateRewardControllerV3.connect(this.dev).emergencyWithdraw(0)
        const { amount: devAfterInfo } = await this.fateRewardControllerV3.userInfo(
          0,
          this.dev.address
        )
        expect(devAfterInfo).to.be.equal(getBigNumber(0))

      })
    })

    describe('claimReward', async () => {
      it('claimReward', async () => {
        const bobInfo = await this.fateRewardControllerV3.userInfo(0, this.bob.address)
        const pool = await this.fateRewardControllerV3.poolInfo(0)
        const pendingUnlocked = bobInfo.amount
            .mul(pool.accumulatedFatePerShare)
            .div(1e12)
            .sub(bobInfo.rewardDebt);

        await expect(this.fateRewardControllerV3.connect(this.bob).claimReward(0))
          .to.emit(this.fateRewardControllerV3, 'ClaimRewards')
          .withArgs(this.bob.address, 0, pendingUnlocked)
      })
    })

    describe('setLockedRewardsData', async () => {
      it('reverted cases:', async () => {
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

      it('success cases:', async () => {
        await this.fateRewardControllerV3.setLockedRewardsData(
          [10, 20],[getBigNumber(1), getBigNumber(98, 16)]
        )
        const lockedRewardsPeriodBlock = await this.fateRewardControllerV3.lockedRewardsPeriodBlocks(0)
        expect(lockedRewardsPeriodBlock).to.be.equal(10)
        const lockedRewardsFeePercent = await this.fateRewardControllerV3.lockedRewardsFeePercents(0)
        expect(lockedRewardsFeePercent).to.be.equal(getBigNumber(1))
      })
    })

    describe('excluded Addresses', async () => {
      it('reverted cases:', async() => {
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

      it('success cases:', async() => {
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

    describe('setFateFeeTo', async () => {
      it('reverted cases:', async () => {
        // when trying to set with not-owner
        await expect(
          this.fateRewardControllerV3.connect(this.dev).setFateFeeTo(this.bob.address)
        ).to.be.revertedWith('Ownable: caller is not the owner')
      }),

      it('success cases:', async () => {
        await this.fateRewardControllerV3.setFateFeeTo(this.bob.address)
        expect(await this.fateRewardControllerV3.fateFeeTo()).to.be.equal(this.bob.address) 
      })
    })

    describe('addLP', async () => {
      it('reverted cases:', async () => {
        const testLP1 = await this.LP.deploy('testlp1', 'TestLP1', getBigNumber(1000))
        await testLP1.deployed()
        const testLP2 = await this.LP.deploy('testlp2', 'TestLP2', getBigNumber(1000))
        await testLP2.deployed()
        const testLP3 = await this.LP.deploy('testlp3', 'TestLP3', getBigNumber(1000))
        await testLP3.deployed()

        // when trying to set with not-owner
        await expect(
          this.fateRewardControllerV3.connect(this.dev).add(1, testLP1.address, true)
        ).to.be.revertedWith('Ownable: caller is not the owner')

        await this.fateRewardControllerV3.add(1, testLP1.address, true)
        // when tyring to add LP token already added
        await expect(
          this.fateRewardControllerV3.add(1, testLP1.address, true)
        ).to.be.revertedWith('add: LP token already added')

        // const testLP1 = await this.LP.deploy('testlp1', 'TestLP1', getBigNumber(0))
        //   await testLP1.deployed()
        //   // when tyring to add invalid LP token
        //   await expect(
        //     this.fateRewardControllerV3.add(1, testLP1.address, true)
        //   ).to.be.revertedWith('add: invalid LP token')

        await expect(
          this.fateRewardControllerV3.connect(this.dev).addMany([testLP1.address, testLP2.address])
        ).to.be.revertedWith('Ownable: caller is not the owner')
      }),

      it('success cases:', async () => {
        const testLP1 = await this.LP.deploy('testlp1', 'TestLP1', getBigNumber(1000))
        await testLP1.deployed()
        const testLP2 = await this.LP.deploy('testlp2', 'TestLP2', getBigNumber(1000))
        await testLP2.deployed()
        const testLP3 = await this.LP.deploy('testlp3', 'TestLP3', getBigNumber(1000))
        await testLP3.deployed()

        let length = await this.fateRewardControllerV3.poolLength()
        await expect(this.fateRewardControllerV3.add(1, testLP1.address, true))
          .to.emit(this.fateRewardControllerV3, 'PoolAdded')
          .withArgs(length, testLP1.address, 1)

        await this.fateRewardControllerV3.addMany([testLP2.address, testLP3.address])
        length = await this.fateRewardControllerV3.poolLength()
        const lastLP1 = await this.fateRewardControllerV3.poolInfo(length - 1)
        const lastLP2 = await this.fateRewardControllerV3.poolInfo(length - 2)
        expect(lastLP2.lpToken).to.be.equal(testLP2.address)
        expect(lastLP1.lpToken).to.be.equal(testLP3.address)
    
      })
    })

    describe('setPool', async () => {
      it('reverted cases:', async () => {
        // when trying to set with not-owner
        await expect(
          this.fateRewardControllerV3.connect(this.dev).set(0, 2, true)
        ).to.be.revertedWith('Ownable: caller is not the owner')

        const testLP = await this.LP.deploy('testlp', 'TestLP', getBigNumber(1000))
        await testLP.deployed()
        await this.fateRewardControllerV3.add(1, testLP.address, true)

        await expect(
          this.fateRewardControllerV3.connect(this.dev).setMany([0, 1], [2, 3])
        ).to.be.revertedWith('Ownable: caller is not the owner')

        await expect(
          this.fateRewardControllerV3.connect(this.dev).setManyWith2dArray([[0, 2], [1, 3]])
        ).to.be.revertedWith('Ownable: caller is not the owner')

      }),

      it('success cases:', async () => {
        await expect(this.fateRewardControllerV3.set(0, 2, true))
          .to.emit(this.fateRewardControllerV3, 'PoolAllocPointSet')
          .withArgs(0, 2)

        const testLP = await this.LP.deploy('testlp', 'TestLP', getBigNumber(1000))
        await testLP.deployed()
        await this.fateRewardControllerV3.add(1, testLP.address, true)

        await this.fateRewardControllerV3.setMany([0, 1], [2, 3])
        let LP1 = await this.fateRewardControllerV3.poolInfo(0)
        let LP2 = await this.fateRewardControllerV3.poolInfo(1)
        expect(LP1.allocPoint.toString()).to.be.equal('2')
        expect(LP2.allocPoint.toString()).to.be.equal('3')

        await this.fateRewardControllerV3.setManyWith2dArray([[0, 3], [1, 4]])
        LP1 = await this.fateRewardControllerV3.poolInfo(0)
        LP2 = await this.fateRewardControllerV3.poolInfo(1)
        expect(LP1.allocPoint.toString()).to.be.equal('3')
        expect(LP2.allocPoint.toString()).to.be.equal('4')
      })
    })

    describe('setMigrator', async () => {
      it('reverted cases:', async () => {
        // when trying to set with not-owner
        await expect(
          this.fateRewardControllerV3.connect(this.dev).setMigrator(this.bob.address)
        ).to.be.revertedWith('Ownable: caller is not the owner')
      }),

      it('success cases:', async () => {
        await expect(this.fateRewardControllerV3.setMigrator(this.bob.address))
          .to.emit(this.fateRewardControllerV3, 'MigratorSet')
          .withArgs(this.bob.address)
      })
    })

})

