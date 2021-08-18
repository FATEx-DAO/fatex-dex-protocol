module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const { address } = await deploy("FateToken", {
    from: deployer,
    args: [deployer, '888888888000000000000000000'],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })

  console.log(`FATE token deployed at ${address}`)
}

module.exports.tags = ["FateToken"]
