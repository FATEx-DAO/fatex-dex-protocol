const { MULTI_SIG_ADDRESSES } = require("../src/constants");
module.exports = async function ({ getChainId, ethers, getNamedAccounts }) {
  const { deployer } = await getNamedAccounts()
  const chainId = await getChainId()

  const vault = await ethers.getContract("Vault")
  const controller = await ethers.getContract("FateRewardController")

  await (await vault.setRewardController(controller.address, { gasLimit: 5198000 })).wait()
  await (await vault.transferOwnership(MULTI_SIG_ADDRESSES.get(chainId), { gasLimit: 5198000 })).wait()
}

module.exports.tags = ["Setter"]
module.exports.dependencies = ["Vault", "FateRewardController"]
