const MULTI_SIG_ADDRESSES = new Map()
MULTI_SIG_ADDRESSES.set("1666600000", "0x4853365bc81f8270d902076892e13f27c27e7266")
MULTI_SIG_ADDRESSES.set("1666700000", "0x4853365bc81f8270d902076892e13f27c27e7266")

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
    const developer = MULTI_SIG_ADDRESSES.get(chainId)
    if (controller.owner() !== developer) {
      await (await controller.transferOwnership(developer, { gasLimit: 5198000 })).wait()
    }
  }

  console.log("FateRewardController Deployed")
}

module.exports.tags = ["FateRewardController"]
module.exports.dependencies = ["UniswapV2Factory", "FateToken", "Vault"]
