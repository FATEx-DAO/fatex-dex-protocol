const { ethers } = require("hardhat")
const { expect } = require("chai")

// yarn test test/RewardSchedule.test.js
describe.only("RewardSchedule", () => {
  const BLOCKS_PER_WEEK = 30 * 60 * 24 * 7
  const startBlock = 10000000

  before(async () => {
    this.signers = await ethers.getSigners()
    this.alice = this.signers[0]
    this.bob = this.signers[1]
    this.dev = this.signers[2]
    this.minter = this.signers[3]

    this.RewardSchedule = await ethers.getContractFactory("RewardScheduleV3")
  })

  beforeEach(async () => {
    console.log(0.92e18)
    this.rewardSchedule = await this.RewardSchedule.deploy(startBlock)
    await this.rewardSchedule.deployed()
  })  

  const getFatePerBlock = async (
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
    const fatePerBlocks = await getFatePerBlock(startBlock, startBlock, startBlock + (BLOCKS_PER_WEEK * 13));
    expect(fatePerBlocks[0].toString()).to.be.equal('8424908424908'); // lockedRewards
    expect(fatePerBlocks[1].toString()).to.be.equal('732600732600'); // unlockedRewards
  })

  it("should work for basic query when _toBlock is before _startBlock", async () => {
    const fatePerBlocks = await getFatePerBlock(startBlock, startBlock - 10, startBlock - 5);
    expect(fatePerBlocks[0].toString()).to.be.equal('0'); // lockedRewards
    expect(fatePerBlocks[1].toString()).to.be.equal('0'); // unlockedRewards
  })

  it("should work for basic query when _fromBlock and _toBlock span multiple weeks", async () => {
    const fatePerBlocks = await getFatePerBlock(startBlock, startBlock + (BLOCKS_PER_WEEK * 13), startBlock + (BLOCKS_PER_WEEK * 16) - 50);
    expect(fatePerBlocks[0].toString()).to.be.equal('111081519043157'); // lockedRewards
    expect(fatePerBlocks[1].toString()).to.be.equal('9659262525491'); // unlockedRewards
  })

  it("should return 0 when _toBlock is before _startBlock", async () => {
    const fatePerBlocks = await getFatePerBlock(startBlock, startBlock, startBlock - 5);
    expect(fatePerBlocks[0].toString()).to.be.equal('0'); // lockedRewards
    expect(fatePerBlocks[1].toString()).to.be.equal('0'); // unlockedRewards
  })

  it("should return 0 when _fromBlock equals _toBlock", async () => {
    const fatePerBlocks = await getFatePerBlock(startBlock, startBlock + (BLOCKS_PER_WEEK * 75), startBlock + (BLOCKS_PER_WEEK * 76));
    expect(fatePerBlocks[0].toString()).to.be.equal('0'); // lockedRewards
    expect(fatePerBlocks[1].toString()).to.be.equal('0'); // unlockedRewards
  })

  it("should return 0 when _fromBlock is after the last block _toBlock", async () => {
    const fatePerBlocks = await getFatePerBlock(startBlock, startBlock + 100, startBlock + 100);
    expect(fatePerBlocks[0].toString()).to.be.equal('0'); // lockedRewards
    expect(fatePerBlocks[1].toString()).to.be.equal('0'); // unlockedRewards
  })

  it("should fail when _fromBlock is after _toBlock", async () => {
    await expect(getFatePerBlock(startBlock, startBlock + 5, startBlock)).to.be.revertedWith('RewardScheduleV3::getFatePerBlock: INVALID_RANGE')
  })
})
