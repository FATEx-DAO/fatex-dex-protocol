const { ethers } = require("hardhat")
const { expect } = require("chai")
const { advanceBlock } = require("./utilities/time")
const { BigNumber } = ethers

// yarn test test/MembershipPoints.test.js
describe("MembershipPoints", () => {
    const epoch_start_block = 1638576000; // block number of 2021.12.4
    before(async () => {
      this.signers = await ethers.getSigners()
      this.alice = this.signers[0]
      this.bob = this.signers[1]
      this.dev = this.signers[2]
      this.minter = this.signers[3]
  
      this.MembershipPoints = await ethers.getContractFactory("MembershipPoints")
    })
  
    beforeEach(async () => {
      this.membershipPoints = await this.MembershipPoints.deploy(epoch_start_block)
      await this.membershipPoints.deployed()
    })

  
    it("should return Points per block", async () => {
        const pointsPerBlock = await this.membershipPoints.POINTS_PER_BLOCK();
        expect(BigNumber.from(pointsPerBlock).toString()).to.equal('80000000000000000');
    })

    it("recordDepositBlock & userPoints", async () => {
        // alice do deposit
        await this.membershipPoints.connect(this.alice).recordDepositBlock(1, this.alice.address);
        await advanceBlock();
        const alicePoints = await this.membershipPoints.userPoints(1, this.bob.address);
        expect(alicePoints).to.not.equal(BigNumber.from(0));
    })

    it("rank with userPoints", async () => {
      await this.membershipPoints.connect(this.alice).recordDepositBlock(1, this.alice.address);
      await advanceBlock();
      await this.membershipPoints.connect(this.bob).recordDepositBlock(1, this.bob.address);
      await advanceBlock();

      await this.membershipPoints.connect(this.alice).rank(1);
      const aliceMembershipInfo = await this.membershipPoints.userMembershipInfo(1, this.alice.address);
      const bobMembershipInfo = await this.membershipPoints.userMembershipInfo(1, this.bob.address);
      
      expect(BigNumber.from(aliceMembershipInfo.rankedNumber).toNumber()).to.equal(0);
      expect(BigNumber.from(bobMembershipInfo.rankedNumber).toNumber()).to.equal(1);
  })
})

