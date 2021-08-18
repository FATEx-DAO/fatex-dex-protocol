const { MULTI_SIG_ADDRESSES, USDC_MAP, ONE_MAP } = require("../src/constants");

module.exports = async function ({ getNamedAccounts, deployments, getChainId }) {
  const { deploy } = deployments

  const { token_deployer } = await getNamedAccounts()

  const chainId = await getChainId()

  await deploy("WETH9Mock", {
    from: token_deployer,
    log: true,
  })

  const { address: multiSigAddress } = await deploy("MultiSig", {
    from: token_deployer,
    args: [[token_deployer], 1],
    log: true,
  })

  const { address: oneAddress } = await deploy('ERC20Mock', {
    from: token_deployer,
    args: ["Harmony", "ONE", "1000000000000000000000000000"],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })
  ONE_MAP.set(chainId, oneAddress)

  const { address: usdcAddress } = await deploy('ERC20Mock', {
    from: token_deployer,
    args: ["USDCoin", "USDC", "1000000000000000"],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })
  USDC_MAP.set(chainId, usdcAddress)

  MULTI_SIG_ADDRESSES.set(chainId, multiSigAddress)

  // await deploy()
}

module.exports.skip = ({ getChainId }) =>
  new Promise(async (resolve, reject) => {
    try {
      const chainId = await getChainId()
      resolve(chainId !== "31337")
    } catch (error) {
      reject(error)
    }
  })

module.exports.tags = ["test"]
