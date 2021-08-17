const ONE_MAP = new Map()
ONE_MAP.set("1666600000", "0xcF664087a5bB0237a0BAd6742852ec6c8d69A27a")
ONE_MAP.set("1666700000", "0x7466d7d0C21Fa05F32F5a0Fa27e12bdC06348Ce2")

const USDC_MAP = new Map()
USDC_MAP.set("1666600000", "0x985458e523db3d53125813ed68c274899e9dfab4")
USDC_MAP.set("1666700000", "0x0e80905676226159cc3ff62b1876c907c91f7395") // technically, this is BUSD on testnet, not USDC

module.exports = async function ({ getNamedAccounts, deployments, ethers, getChainId }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const chainId = await getChainId()

  await deploy('UniswapV2Factory', {
    from: deployer,
    args: [deployer],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })

  const factory = await ethers.getContract("UniswapV2Factory")

  const fateAddress = (await ethers.getContract("FateToken")).address
  const oneAddress = ONE_MAP.get(chainId)
  const usdcAddress = USDC_MAP.get(chainId)

  await (await factory.createPair(fateAddress, oneAddress)).wait()
  await (await factory.createPair(oneAddress, usdcAddress)).wait()
}

module.exports.tags = ["UniswapV2Factory", "FateToken"]
