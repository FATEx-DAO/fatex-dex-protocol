module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const fate = await deployments.get("FateToken")

  await deploy("Vault", {
    from: deployer,
    args: [fate.address, '0x0000000000000000000000000000000000000000'],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })
}

module.exports.tags = ["Vault"]
module.exports.dependencies = ["FateToken"]
