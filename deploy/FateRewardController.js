const { ONE_MAP, USDC_MAP, MULTI_SIG_ADDRESSES } = require("../src/constants");

module.exports = async function ({ ethers, deployments, getNamedAccounts, getChainId }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const chainId = await getChainId()

  const fate = await deployments.get("FateToken")
  const emissionSchedule = await deployments.get("EmissionSchedule")
  const vault = await deployments.get("Vault")

  console.log("Deploying FateRewardController", deployer)

  const { address, newlyDeployed } = await deploy("FateRewardController", {
    from: deployer,
    args: [fate.address, emissionSchedule.address, vault.address],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })

  if (newlyDeployed) {
    const fate = await ethers.getContract("FateToken")

    if ((await fate.owner()) !== address) {
      // Transfer FATE Ownership to Chef
      await (await fate.transferOwnership(address, { gasLimit: 5198000 })).wait()
    }


    // Transfer ownership of FateRewardController to dev
    const controller = await ethers.getContract("FateRewardController")
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

  console.log("FateRewardController Deployed")
}

module.exports.tags = ["FateRewardController"]
module.exports.dependencies = ["UniswapV2Factory", "FateToken", "Vault"]
