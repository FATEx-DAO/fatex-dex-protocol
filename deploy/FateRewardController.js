const MULTI_SIG_ADDRESSES = new Map()
MULTI_SIG_ADDRESSES.set("1666600000", "0x4853365bc81f8270d902076892e13f27c27e7266")
MULTI_SIG_ADDRESSES.set("1666700000", "0x4853365bc81f8270d902076892e13f27c27e7266")

const ONE_MAP = new Map()
ONE_MAP.set("1666600000", "0xcF664087a5bB0237a0BAd6742852ec6c8d69A27a")
ONE_MAP.set("1666700000", "0x7466d7d0C21Fa05F32F5a0Fa27e12bdC06348Ce2")

const USDC_MAP = new Map()
USDC_MAP.set("1666600000", "0x985458e523db3d53125813ed68c274899e9dfab4")
USDC_MAP.set("1666700000", "0x0e80905676226159cc3ff62b1876c907c91f7395") // technically, this is BUSD on testnet, not USDC

module.exports = async function ({ ethers, deployments, getNamedAccounts, getChainId }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const chainId = await getChainId()

  const fate = await deployments.get("FateToken")
  const emissionSchedule = await deployments.get("EmissionSchedule")
  const vault = await deployments.get("Vault")

  console.log("Deploying FateRewardController", deployer)

  const { address, newlyDeployed } = await deploy("FateRewardController", {
    from: deployer,
    args: [fate.address, emissionSchedule.address, vault.address],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })

  if (newlyDeployed) {
    const fate = await ethers.getContract("FateToken")

    if ((await fate.owner()) !== address) {
      // Transfer FATE Ownership to Chef
      await (await fate.transferOwnership(address, { gasLimit: 5198000 })).wait()
    }


    // Transfer ownership of FateRewardController to dev
    const controller = await ethers.getContract("FateRewardController")
    const factory = await ethers.getContract("UniswapV2Factory")

    const oneAddress = ONE_MAP.get(chainId)
    const usdcAddress = USDC_MAP.get(chainId)

    const fate_one_address = await factory.getPair(fate.address, oneAddress)
    const one_usdc_address = await factory.getPair(oneAddress, usdcAddress)

    await (await controller.add('10000', fate_one_address, /* update pools */ false)).wait()
    await (await controller.add('10000', one_usdc_address, /* update pools */ true)).wait()

    const developer = MULTI_SIG_ADDRESSES.get(chainId)
    if ((await controller.owner()) !== developer) {
      await (await controller.transferOwnership(developer, { gasLimit: 5198000 })).wait()
    }
  }

  console.log("FateRewardController Deployed")
}

module.exports.tags = ["FateRewardController"]
module.exports.dependencies = ["UniswapV2Factory", "FateToken", "Vault"]
