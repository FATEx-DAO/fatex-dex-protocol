module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const timelockAddress = (await deployments.get("Timelock")).address
  const fateAddress = (await deployments.get("FateToken")).address

  await deploy("GovernorAlpha", {
    from: deployer,
    args: [timelockAddress, fateAddress],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })
}

module.exports.tags = ["GovernorAlpha"]
module.exports.dependencies = ["Timelock", "FateToken"]
