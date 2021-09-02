module.exports = async function ({ getNamedAccounts, deployments, ethers }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const timelock = await ethers.getContract("Timelock")
  const fateAddress = (await deployments.get("FateToken")).address
  const xFateAddress = (await deployments.get("XFateToken")).address

  const { address } = await deploy("GovernorAlpha", {
    from: deployer,
    args: [timelock.address, fateAddress, xFateAddress],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })
  // FOR PROPOSAL
  // 0x000000000000000000000000CaCDaDe3AAa92582C3161ae5A9Fa3bB7e788FDF80000000000000000000000000000000000000000000000000de0b6b3a7640000

  await (await timelock.setPendingAdmin(address, { from: deployer })).wait();

  const governorAlpha = await ethers.getContract("GovernorAlpha")

  await (await governorAlpha.acceptAdmin()).wait()
}

module.exports.tags = ["GovernorAlpha"]
module.exports.dependencies = ["Timelock", "FateToken"]
