const { deployContract, contractAt, sendTxn, writeTmpAddressesByHarmony, readTmpAddresses } = require("../shared/helpers")
const { expandDecimals } = require('../shared/utilities');
const {ethers} = require("ethers");
const hre = require("hardhat");

async function advanceBlock() {
    return ethers.provider.send("evm_mine", [])
}

async function advanceBlockTo(blockNumber) {
    for (let i = await ethers.provider.getBlockNumber(); i < blockNumber; i++) {
        await advanceBlock()
    }
}

async function main() {
    const vault_address = "0xe58d9f09ae23f2bfd1e3ff92df0a9dd087b8c588"
    const account = "0xe58d9f09ae23f2bfd1e3ff92df0a9dd087b8c588"
    const feeTo = "0x275e1b68048dca746240b82B09d0B3335d9Adc33"
    //================== Deploy Process =========================
    const totalSupply = expandDecimals('888888888', 18)
    const fateToken = await deployContract('FateToken', [account, totalSupply])
    // const lpToken = await deployContract('ERC20Mock', ['lp', 'LP', expandDecimals(1000000, 18)])
    // const rewardSchedule = await deployContract('RewardScheduleV3', [])
    // const fateRewardControllerV2 = await deployContract('FateRewardController',
    //     [
    //         fateToken.address,
    //         rewardSchedule.address,
    //         vault_address]
    // )
    // const mockLpTokenFactory = await deployContract('MockLpTokenFactory', [])
    // const fateRewardControllerV3 = await deployContract('FateRewardControllerV3', [
    //     fateToken.address,
    //     rewardSchedule.address,
    //     vault_address,
    //     [fateRewardControllerV2.address],
    //     mockLpTokenFactory.address,
    //     feeTo]
    // )
    // writeTmpAddressesByHarmony({
    //     fateTokenAddress: fateToken.address,
    //     lpTokenAddress: lpToken.address,
    //     rewardScheduleV3Address: rewardSchedule.address,
    //     mockLpTokenFactoryAddress: mockLpTokenFactory.address,
    //     fateRewardControllerAddress: fateRewardControllerV2.address,
    //     fateRewardControllerV3Address: fateRewardControllerV3.address,
    // })
    //======================================================

}



main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

