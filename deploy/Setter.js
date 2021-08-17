const MULTI_SIG_ADDRESSES = new Map()
MULTI_SIG_ADDRESSES.set("1666600000", "0x4853365bc81f8270d902076892e13f27c27e7266")
MULTI_SIG_ADDRESSES.set("1666700000", "0x4853365bc81f8270d902076892e13f27c27e7266")

module.exports = async function ({ getChainId, ethers }) {
  const chainId = await getChainId()

  const vault = await ethers.getContract("Vault")
  const controller = await ethers.getContract("FateRewardController")

  await (await vault.setRewardController(controller.address, { gasLimit: 5198000 })).wait()
  await (await vault.transferOwnership(MULTI_SIG_ADDRESSES.get(chainId), { gasLimit: 5198000 })).wait()
}

module.exports.tags = ["Setter"]
module.exports.dependencies = ["Vault", "FateRewardController"]
