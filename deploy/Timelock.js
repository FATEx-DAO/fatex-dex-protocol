module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const delay = (60 * 60 * 24 * 2).toString()

  await deploy("Timelock", {
    from: deployer,
    args: [deployer, delay],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })
}

module.exports.tags = ["Timelock"]
