const SUSHI_SWAP_ROUTER = new Map()
SUSHI_SWAP_ROUTER.set('1666600000', '0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506')
SUSHI_SWAP_ROUTER.set('1666700000', '0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506')

const VIPER_SWAP_ROUTER = new Map()
VIPER_SWAP_ROUTER.set('1666600000', '0xf012702a5f0e54015362cBCA26a26fc90AA832a3')
VIPER_SWAP_ROUTER.set('1666700000', '0xda3DD48726278a7F478eFaE3BEf9a5756ccdb4D0')

const SUSHI_INIT_CODE_HASH = '0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303'

const VIPER_INIT_CODE_HASH = '0x162f79e638367cd45a118c778971dfd8d96c625d2798d3b71994b035cfe9b6dc'

module.exports = async function ({ getNamedAccounts, getChainId, deployments }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const chainId = await getChainId()

  const fateRouterAddress = (await deployments.get('UniswapV2Router02')).address

  const sushiRouterAddress = SUSHI_SWAP_ROUTER.get(chainId)
  if (sushiRouterAddress) {
    await deploy('LiquidityMigrator', {
      from: deployer,
      args: [sushiRouterAddress, fateRouterAddress, SUSHI_INIT_CODE_HASH],
      log: true,
      deterministicDeployment: false,
      gasLimit: 5198000,
    })
  }

  const viperRouterAddress = VIPER_SWAP_ROUTER.get(chainId)
  if (viperRouterAddress) {
    await deploy('LiquidityMigrator', {
      from: deployer,
      args: [viperRouterAddress, fateRouterAddress, VIPER_INIT_CODE_HASH],
      log: true,
      deterministicDeployment: false,
      gasLimit: 5198000,
    })
  }
}

module.exports.tags = ['LiquidityMigrators']
module.exports.dependencies = ['UniswapV2Router02']
