const { ethers } = require("hardhat")
const { expect } = require("chai")
const time = require('./utilities/time')
const testMerkleRoot = require('./utilities/test-merkle-root.json')

describe("MerkleDistributor", function () {
  before(async function () {
    this.signers = await ethers.getSigners()
    this.alice = this.signers[0]
    this.bob = this.signers[1]
    this.dev = this.signers[2]
    this.minter = this.signers[3]

    this.ERC20Mock = await ethers.getContractFactory("ERC20Mock", this.minter)
    this.MerkleDistributor = await ethers.getContractFactory("MerkleDistributor")
    this.startTimestamp = Math.floor(new Date().getTime() / 1000)
  })

  beforeEach(async function () {
    this.weth = await this.ERC20Mock.deploy("WETH", "WETH", "100000000000000000000")
    await this.weth.deployed()

    this.amount = ethers.BigNumber.from(testMerkleRoot.claims[this.alice.address].amount)
    this.oneYearSeconds = ethers.BigNumber.from(86400 * 365)
    this.merkleDistributor = await this.MerkleDistributor.deploy(
      this.weth.address,
      testMerkleRoot.merkleRoot,
      this.startTimestamp,
      this.oneYearSeconds,
    )
    await this.weth.transfer(this.merkleDistributor.address, "100000000000000000000")
  });

  it("should work for various durations", async function () {
    await time.advanceTime(86400 * 73)
    await this.merkleDistributor.connect(this.alice).claim(
      testMerkleRoot.claims[this.alice.address].index,
      this.alice.address,
      testMerkleRoot.claims[this.alice.address].amount,
      testMerkleRoot.claims[this.alice.address].proof,
    )
    let latestTimestamp = await time.latestTimestamp()
    let duration = latestTimestamp.sub(this.startTimestamp)
    expect((await this.weth.balanceOf(this.alice.address))).to.eq(this.amount.mul(duration).div(this.oneYearSeconds))
    expect((await this.weth.balanceOf(this.alice.address))).to.eq(await this.merkleDistributor.getClaimed(this.alice.address))

    await time.advanceTime(86400 * 100)
    await this.merkleDistributor.connect(this.alice).claim(
      testMerkleRoot.claims[this.alice.address].index,
      this.alice.address,
      testMerkleRoot.claims[this.alice.address].amount,
      testMerkleRoot.claims[this.alice.address].proof,
    )
    latestTimestamp = await time.latestTimestamp()
    duration = latestTimestamp.sub(this.startTimestamp)
    expect((await this.weth.balanceOf(this.alice.address))).to.eq(this.amount.mul(duration).div(this.oneYearSeconds))
    expect((await this.weth.balanceOf(this.alice.address))).to.eq(await this.merkleDistributor.getClaimed(this.alice.address))

    await time.advanceTime(86400 * 365)
    await this.merkleDistributor.connect(this.alice).claim(
      testMerkleRoot.claims[this.alice.address].index,
      this.alice.address,
      testMerkleRoot.claims[this.alice.address].amount,
      testMerkleRoot.claims[this.alice.address].proof,
    )
    duration = 86400 * 365
    expect((await this.weth.balanceOf(this.alice.address))).to.eq(this.amount.mul(duration).div(this.oneYearSeconds))
    expect((await this.weth.balanceOf(this.alice.address))).to.eq(await this.merkleDistributor.getClaimed(this.alice.address))
  })
});
