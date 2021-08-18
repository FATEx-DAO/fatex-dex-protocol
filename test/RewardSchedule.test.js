const { ethers } = require("hardhat")
const { expect } = require("chai")
const { BigNumberish } = require("ethers");

describe("EmissionSchedule", () => {
  const startBlock = 10_000_000
  before(async () => {
    this.signers = await ethers.getSigners()
    this.alice = this.signers[0]
    this.bob = this.signers[1]
    this.dev = this.signers[2]
    this.minter = this.signers[3]

    this.RewardSchedule = await ethers.getContractFactory("RewardSchedule")
  })

  beforeEach(async () => {
    this.rewardSchedule = await this.RewardSchedule.deploy()
    await this.rewardSchedule.deployed()
  })

  const BLOCKS_PER_WEEK = 30 * 60 * 24 * 7

  const getFatePerBlock = (
    _startBlock,
    _fromBlock,
    _toBlock,
  )  => {
    return this.rewardSchedule.getFatePerBlock(_startBlock, _fromBlock, _toBlock)
  }

  it("should return correct number of weeks", async () => {
    expect(await this.rewardSchedule.rewardsNumberOfWeeks()).to.equal('72')
  })

  it("should return correct number of blocks per week", async () => {
    expect(await this.rewardSchedule.BLOCKS_PER_WEEK()).to.equal(BLOCKS_PER_WEEK.toString())
  })

  it("should work for basic query", async () => {
    expect(await getFatePerBlock(startBlock, startBlock, startBlock + 100)).to.equal('720000000000000000000')
  })

  it("should work for basic query when _fromBlock is before _startBlock", async () => {
    expect(await getFatePerBlock(startBlock, startBlock - 10, startBlock + 100)).to.equal('720000000000000000000')
  })

  it("should work for basic query when _toBlock is before _startBlock", async () => {
    expect(await getFatePerBlock(startBlock, startBlock - 10, startBlock - 5)).to.equal('0')
  })

  it("should work for basic query when _fromBlock and _toBlock span multiple weeks", async () => {
    // _fromBlock = 100
    // _toBlock = 907,150
    // diff = 907,050
    // (10,882,800 + 11,040,624 + 11,192,997) / (_toBlock / _fromBlock) * 0.2
    expect(await getFatePerBlock(startBlock, startBlock + 100, startBlock + (BLOCKS_PER_WEEK * 3) - 50)).to.equal('7302005622622788159')
  })

  it("should work for basic query when _toBlock is after highest index", async () => {
    // 509.5 FATE per WEEK in total @ 80% lockup --> 101.9
    // 72 FATE per week at last week --> 173.9
    // 173.9 * BLOCKS_PER_WEEK --> 52,587,360
    // 52,587,360 / (72 weeks * 302,400 blocks per week - 1 block exclusivity in the end) --> 2.415277 FATE per block
    expect(await getFatePerBlock(startBlock, startBlock, startBlock + (BLOCKS_PER_WEEK * 75))).to.equal('2415277888708750767')
  })

  it("should return 0 when _toBlock is before _startBlock", async () => {
    expect(await getFatePerBlock(startBlock, startBlock, startBlock - 5)).to.equal('0')
  })

  it("should return 0 when _fromBlock equals _toBlock", async () => {
    expect(await getFatePerBlock(startBlock, startBlock + 100, startBlock + 100)).to.equal('0')
  })

  it("should fail when _fromBlock is after _toBlock", async () => {
    await expect(getFatePerBlock(startBlock, startBlock + 5, startBlock)).to.be.revertedWith('EmissionSchedule::getFatePerBlock: INVALID_RANGE')
  })
})
