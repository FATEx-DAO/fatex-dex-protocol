const VIPER_SWAP_ROUTER = new Map()
VIPER_SWAP_ROUTER.set("1666600000", "0xf012702a5f0e54015362cBCA26a26fc90AA832a3")
VIPER_SWAP_ROUTER.set("1666700000", "0xda3DD48726278a7F478eFaE3BEf9a5756ccdb4D0")

module.exports = async function ({ getNamedAccounts, getChainId, deployments }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const chainId = await getChainId()

  const uniswapRouterAddress = VIPER_SWAP_ROUTER.get(chainId)

  const fateRouterAddress = (await deployments.get("UniswapV2Router02")).address

  if (uniswapRouterAddress) {
    await deploy("LiquidityMigrator", {
      from: deployer,
      args: [uniswapRouterAddress, fateRouterAddress],
      log: true,
      deterministicDeployment: false,
      gasLimit: 5198000,
    })
  }
}

module.exports.tags = ["LiquidityMigrator"]
module.exports.dependencies = ["UniswapV2Factory", "UniswapV2Router02"]
