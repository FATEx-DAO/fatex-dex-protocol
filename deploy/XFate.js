module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const fate = await deployments.get("FateToken")

  await deploy("XFateToken", {
    from: deployer,
    args: [fate.address],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })
}

module.exports.tags = ["XFateToken"]
module.exports.dependencies = ["UniswapV2Factory", "FateToken"]
