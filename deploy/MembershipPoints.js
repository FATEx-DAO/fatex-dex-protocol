module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const epoch_start_block = 1638576000; // block number of 2021.12.4

  const { address } = await deploy("MembershipPoints", {
    from: deployer,
    args: [epoch_start_block],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })

  console.log(`MembershipPoints deployed at ${address}`)
}

module.exports.tags = ["MembershipPoints"]
