const { ONE_MAP, USDC_MAP, MULTI_SIG_ADDRESSES } = require("../src/constants");

module.exports = async function ({ ethers, deployments, getNamedAccounts, getChainId }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const chainId = await getChainId()

  const fate = await deployments.get("FateToken")
  // const rewardSchedule = await deployments.get("RewardScheduleV3")
  const vault = await deployments.get("Vault")

  console.log("Deploying FateRewardControllerV3", deployer)

  const { address, newlyDeployed } = await deploy("FateRewardControllerV3", {
    from: deployer,
    args: [
      fate.address,
      '0xfDdE60866508263e30C769e8592BB0f8C3274ba7', // rewardSchedule (should be replaced with mainnet addr)
      vault.address,
      ['0x04170495EA41288225025De3CDFE9A9799121861'], // oldControllers (should be replaced with mainnet addr)
      '0xd9D9a75f0eFe0A2dD580f212005a8211CC8dF4FD', // mockLPFactory (should be replaced with mainnet addr)
      '0xabB6D4a1015e291b1bc71e7e56ff2c9204665b07' // vault (should be replaced with mainnet addr)
    ],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })

  if (newlyDeployed) {
    const fate = await ethers.getContract("FateToken")

    // Transfer ownership of FateRewardControllerV3 to dev
    const controller = await ethers.getContract("FateRewardControllerV3")
    const factory = await ethers.getContract("UniswapV2Factory")

    const oneAddress = ONE_MAP.get(chainId)
    const usdcAddress = USDC_MAP.get(chainId)

    const fate_one_address = await factory.getPair(fate.address, oneAddress)
    const one_usdc_address = await factory.getPair(oneAddress, usdcAddress)

    await (await controller.add('10000', fate_one_address, /* update pools */ false)).wait()
    await (await controller.add('10000', one_usdc_address, /* update pools */ true)).wait()

    const developer = MULTI_SIG_ADDRESSES.get(chainId)
    if ((await controller.owner()) !== developer) {
      await (await controller.transferOwnership(developer, { gasLimit: 5198000 })).wait()
    }
  }

  console.log(`FateRewardControllerV3 Deployed: ${address}`)
}

module.exports.tags = ["FateRewardControllerV3"]
module.exports.dependencies = ["UniswapV2Factory", "FateToken", "Vault", "RewardScheduleV3"]
