module.exports = async function ({ getNamedAccounts, deployments, ethers }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const timelock = await ethers.getContract("Timelock")
  const fateAddress = (await deployments.get("FateToken")).address

  const { address } = await deploy("GovernorAlpha", {
    from: deployer,
    args: [timelock.address, fateAddress],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })

  await (await timelock.setPendingAdmin(address, { from: deployer })).wait();

  const governorAlpha = await ethers.getContract("GovernorAlpha")

  await (await governorAlpha.acceptAdmin()).wait()
}

module.exports.tags = ["GovernorAlpha"]
module.exports.dependencies = ["Timelock", "FateToken"]
