const { deployContract, contractAt, sendTxn, writeTmpAddresses, readTmpAddresses } = require("../shared/helpers")
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
    // const totalSupply = expandDecimals('888888888', 18)
    // const fateToken = await deployContract('FateToken', [account, totalSupply])
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
    // writeTmpAddresses({
    //     fateTokenAddress: fateToken.address,
    //     lpTokenAddress: lpToken.address,
    //     rewardScheduleV3Address: rewardSchedule.address,
    //     mockLpTokenFactoryAddress: mockLpTokenFactory.address,
    //     fateRewardControllerAddress: fateRewardControllerV2.address,
    //     fateRewardControllerV3Address: fateRewardControllerV3.address,
    // })
    //======================================================
    const {
        fateTokenAddress,
        lpTokenAddress,
        rewardScheduleV3Address,
        mockLpTokenFactoryAddress,
        fateRewardControllerAddress,
        fateRewardControllerV3Address
    } = readTmpAddresses();



    const fateToken = await contractAt('FateToken', fateTokenAddress);
    const lpToken = await contractAt('ERC20Mock', lpTokenAddress);
    const rewardScheduleV3 = await contractAt('RewardScheduleV3', rewardScheduleV3Address);
    const fateRewardController = await contractAt('FateRewardController', fateRewardControllerAddress);
    const mockLpTokenFactory = await contractAt('MockLpTokenFactory', mockLpTokenFactoryAddress);
    const fateRewardControllerV3 = await contractAt('FateRewardControllerV3', fateRewardControllerV3Address);

    const poolLength = await fateRewardControllerV3.poolLength()
    console.log("============== poolLength ======================")
    console.log("poolLength: ", poolLength.toNumber())

    const getPoolInfoId = await fateRewardControllerV3.getPoolInfoId(lpToken.address);
    console.log("============== getPoolInfoId ======================")
    console.log("poolInfoId: ", getPoolInfoId.toString())

    const balanceOf = await lpToken.balanceOf(account);
    console.log("============== balance of LP Token ======================")
    console.log("balance: ", balanceOf.toString())

    console.log("========================== Add LP ===================================");
    await sendTxn(fateRewardControllerV3.add(1, lpToken.address, true), "FateRewardControllerV3 addLP")

    const pendingLockedFate = await fateRewardControllerV3.pendingLockedFate(0, account)
    console.log("============== pendingLockedFate ======================")
    console.log("pendingLockedFate: ", pendingLockedFate.toString())

    const getFeeReserves = await fateRewardControllerV3.getFeeReserves(lpToken.address);
    console.log("============== getFeeReserves ======================")
    console.log("previous feeReserves: ", getFeeReserves.toString())

    const previousUserInfo = await fateRewardControllerV3.userInfo(0, account);
    console.log("============== User Info before Deposit ======================")
    console.log("Amount: ", previousUserInfo[0].toString(), ",  rewardDebt: ", previousUserInfo[1].toString());

    console.log("========================== Deposit ===================================");
    await sendTxn(lpToken.approve(fateRewardControllerV3.address, expandDecimals(10000, 18)), "approve to send");
    await sendTxn(fateRewardControllerV3.deposit(0, expandDecimals(10000, 18)), "Deposit => amount : " + (expandDecimals(10000, 18)).toString())

    const afterUserInfo = await fateRewardControllerV3.userInfo(0, account);
    console.log("============== User Info After Deposit ======================")
    console.log("Amount: ", afterUserInfo[0].toString(), ",  rewardDebt: ", afterUserInfo[1].toString());

    const getUserInfo = await fateRewardControllerV3._getUserInfo(0, account)
    console.log("============== User Info ======================")
    console.log("amount: ", getUserInfo[0].toString(), "rewardDebt: ", getUserInfo[1].toString(), "lockedRewardDebt: ", getUserInfo[2].toString())

    const poolInfo = await fateRewardControllerV3.poolInfo(0);
    console.log("============== Pool Info ======================")
    console.log("lpToken: ", poolInfo[0], ", allocPoint: ", poolInfo[1].toString(), ", lastRewardBlock: ", poolInfo[2].toString(), ", accumulatedFatePerShare: ", poolInfo[3].toString(), ", accumulatedLockedFatePerShare: ", poolInfo[4].toString())

    const getLPWithdrawFeePercent1 = await fateRewardControllerV3.getLPWithdrawFeePercent(0, account)
    console.log("============== LP Withdraw FeePercent before Withdraw ======================")
    console.log("feePercent: ", getLPWithdrawFeePercent1.toString());

    console.log("========================== Withdraw ===================================");
    await sendTxn(fateRewardControllerV3.withdraw(0, expandDecimals(9000, 18), { from:account }), "Withdraw => amount : " + (expandDecimals(9000, 18)).toString())

    const getFeeReserves2 = await fateRewardControllerV3.getFeeReserves(lpToken.address);
    console.log("============== getFeeReserves ======================")
    console.log("current feeReserves: ", getFeeReserves2.toString())

    const getLPWithdrawFeePercent2 = await fateRewardControllerV3.getLPWithdrawFeePercent(0, account)
    console.log("============== LP Withdraw FeePercent after Withdraw ======================")
    console.log("feePercent: ", getLPWithdrawFeePercent2.toString());

    const epochEndBlock = await rewardScheduleV3.epochEndBlock();
    console.log("============== epochEndBlock ======================")
    console.log("epochEndBlock: ", epochEndBlock.toString())

    const getLockedRewardsFeePercent = await fateRewardControllerV3.getLockedRewardsFeePercent(0, account);
    console.log("============== getLockedRewardsFeePercent ======================")
    console.log("LockedRewardsFeePercent: ", getLockedRewardsFeePercent.toString());

    const getFateAtIndex = await rewardScheduleV3.getFateAtIndex(14);
    console.log("============== getFateAtIndex ======================")
    console.log("first: ", getFateAtIndex[0].toString(), ", second: ", getFateAtIndex[1].toString());

    // await hre.run("verify:verify", {
    //     address: lpToken.address,
    //     constructorArguments: ['lp', 'LP', expandDecimals(1000000, 18)],
    // });
    // await hre.run("verify:verify", {
    //     address: fateRewardControllerV3.address,
    //     constructorArguments: [
    //         fateTokenAddress,
    //         rewardScheduleV3Address,
    //         vault_address,
    //         [fateRewardControllerAddress],
    //         mockLpTokenFactory.address,
    //         feeTo]
    // });
    // await sendTxn(lpToken.transferFrom(account, fateRewardControllerV3Address, "900000000000000", {from : account}), "manual transfer")
    // const userMembershipInfo = await fateRewardControllerV3.userMembershipInfo(0, account)
    // console.log("userMembershipInfo: ", userMembershipInfo[0].toString(), userMembershipInfo[1].toString())
    // const curren_block = await fateRewardControllerV3.getBlockNumber();
    // console.log("current block: ", curren_block.toString())
}



main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

