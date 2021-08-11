module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const { deploy } = deployments

  const { deployer, dev } = await getNamedAccounts()

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

    // Transfer FATE Ownership to Chef
    await (await fate.transferOwnership(address, { gasLimit: 5198000 })).wait()

    // Transfer ownership of FateRewardController to dev
    const controller = await ethers.getContract("FateRewardController")
    await (await controller.transferOwnership(dev, { gasLimit: 5198000 })).wait()
  }

  console.log("FateRewardController Deployed")
}

module.exports.tags = ["FateRewardController"]
module.exports.dependencies = ["UniswapV2Factory", "FateToken"]
