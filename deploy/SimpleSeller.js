const { MULTI_SIG_ADDRESSES } = require("../src/constants");

module.exports = async function ({ getChainId, ethers, getNamedAccounts, deployments }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()
  const chainId = await getChainId()

  const fate = await ethers.getContract("FateToken")
  const router = await ethers.getContract("UniswapV2Router02")

  await deploy("SimpleSeller", {
    from: deployer,
    args: [fate.address, router.address, "0x05eEE03F9A3Fa10aAC2921451421A9f4e37EaBbc"],
    deterministicDeployment: false,
  })

  const seller = await ethers.getContract("SimpleSeller")
  await (await seller.transferOwnership(MULTI_SIG_ADDRESSES.get(chainId))).wait()
}

module.exports.tags = ["SimpleSeller"]
module.exports.dependencies = ["Vault", "FateRewardController", "UniswapV2Router02"]
