const SUSHI_SWAP_ROUTER = new Map()
SUSHI_SWAP_ROUTER.set("1666600000", "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506")
SUSHI_SWAP_ROUTER.set("1666700000", "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506")

module.exports = async function ({ getNamedAccounts, getChainId, deployments }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const chainId = await getChainId()

  const uniswapRouterAddress = SUSHI_SWAP_ROUTER.get(chainId)

  const fateRouterAddress = (await deployments.get("UniswapV2Router02")).address

  await deploy("LiquidityMigrator", {
    from: deployer,
    args: [uniswapRouterAddress, fateRouterAddress],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })
}

module.exports.tags = ["LiquidityMigrator"]
module.exports.dependencies = ["UniswapV2Factory", "UniswapV2Router02"]
