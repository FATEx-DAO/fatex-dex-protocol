const WETH = {
  "1": '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
  "3": "0xc778417E063141139Fce010982780140Aa0cD5Ab",
  "4": "0xc778417E063141139Fce010982780140Aa0cD5Ab",
  "5": "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6",
  "42": "0xd0A1E359811322d97991E03f863a0C30C2cF029C",
  "1287": "0x1Ff68A3621C17a38E689E5332Efcab9e6bE88b5D",
  "79377087078960": "0xf8456e5e6A225C2C1D74D8C9a4cB2B1d5dc1153b",
  "1666600000": "0xcf664087a5bb0237a0bad6742852ec6c8d69a27a", // harmony mainnet shard 0 wONE
  "1666700000": "0x7466d7d0c21fa05f32f5a0fa27e12bdc06348ce2", // harmony testnet shard 0 wONE
}

const MULTI_SIG_ADDRESSES = new Map()
MULTI_SIG_ADDRESSES.set("1666600000", "0x4853365bc81f8270d902076892e13f27c27e7266")
MULTI_SIG_ADDRESSES.set("1666700000", "0x4853365bc81f8270d902076892e13f27c27e7266")

module.exports = async function ({ ethers, getNamedAccounts, deployments, getChainId }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const chainId = await getChainId()

  const factory = await ethers.getContract("UniswapV2Factory")
  const xFate = await ethers.getContract("XFateToken")
  const fate = await ethers.getContract("FateToken")
  const wethAddress = chainId in WETH ? WETH[chainId] : (await deployments.get("WETH9Mock")).address
  const developer = MULTI_SIG_ADDRESSES.get(chainId)

  const { address, newlyDeployed } = await deploy("FeeTokenConverterToFate", {
    from: deployer,
    args: [factory.address, xFate.address, fate.address, wethAddress],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })

  if (newlyDeployed) {
    // Transfer ownership of FeeTokenConverterToFate to dev
    const feeConverter = await ethers.getContract("FeeTokenConverterToFate")
    console.log("Setting feeConverter owner")
    await (await feeConverter.transferOwnership(developer, { gasLimit: 5198000 })).wait()

    // Set FeeTo to feeConverter
    console.log("Setting factory feeTo to feeConverter address")
    await (await factory.setFeeTo(address, { gasLimit: 5198000 })).wait()
  }
}

module.exports.tags = ["FeeTokenConverterToFate"]
module.exports.dependencies = ["UniswapV2Factory", "XFateToken", "FateToken"]
