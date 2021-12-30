const { ethers, network } = require("hardhat")
const { expect } = require("chai")

describe("RewardScheduleV3", () => {
    const startBlock = 0;
    const fromIndex = 15;
    const toIndex = 16

    before(async() => {
        this.RewardScheduleV3 = await ethers.getContractFactory("RewardScheduleV3")
    })

    beforeEach(async() => {
        try{
            this.rewardScheduleV3 = await this.RewardScheduleV3.deploy(startBlock);
        }
        catch(e){
            console.log(e)
        }
    })

    describe("Fate Reward Per Block", () => {
        it("revert case", async () => {
            await expect(this.rewardScheduleV3.getFatePerBlock(
                startBlock,
                toIndex,
                fromIndex)).to.be.revertedWith("RewardScheduleV3::getFatePerBlock: INVALID_RANGE");
        })
    })
})