const { ONE_MAP, USDC_MAP } = require("../src/constants");

module.exports = async function ({ getNamedAccounts, deployments, ethers, getChainId }) {
  const { deploy } = deployments

  const { deployer, token_deployer } = await getNamedAccounts()

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

  let oneAddress = ONE_MAP.get(chainId)
  let usdcAddress = USDC_MAP.get(chainId)

  await (await factory.createPair(fateAddress, oneAddress)).wait()
  await (await factory.createPair(oneAddress, usdcAddress)).wait()
}

module.exports.tags = ["UniswapV2Factory"]
module.exports.dependencies = ["FateToken", "test"]
