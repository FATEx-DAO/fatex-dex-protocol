module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const { address } = await deploy("RewardSchedule", {
    from: deployer,
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })
}

module.exports.tags = ["RewardSchedule"]
module.exports.dependencies = ["UniswapV2Factory"]
