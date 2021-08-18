const { MULTI_SIG_ADDRESSES } = require("../src/constants");

function getStartTimestamp() {
  return Math.floor(new Date().getTime() / 1000)
}

module.exports = async function ({ getNamedAccounts, ethers, deployments, getChainId }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const chainId = await getChainId()
  const multiSig = MULTI_SIG_ADDRESSES.get(chainId)

  const beneficiary1 = "0xCaCDaDe3AAa92582C3161ae5A9Fa3bB7e788FDF8"
  const beneficiary2 = "0x4F5Fbb56314cB48fA4848bf1e0433F0DD8A12C49"
  const founderBeneficiaryAddress = "0x05eEE03F9A3Fa10aAC2921451421A9f4e37EaBbc"
  const cliffDuration = (60 * 60 * 24 * 182).toString() // 6 months in seconds
  const startTimestamp = getStartTimestamp()
  const totalDuration = (60 * 60 * 24 * 365).toString() // 1 year in seconds
  const revocable = true

  const { address: lockupAddress1 } = await deploy("TokenLockup", {
    from: deployer,
    args: [beneficiary1, startTimestamp, cliffDuration, totalDuration, revocable],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })
  const { address: lockupAddress2 } = await deploy("TokenLockup", {
    from: deployer,
    args: [beneficiary2, startTimestamp, cliffDuration, totalDuration, revocable],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })
  const { address: fgcdAddress } = await deploy("TokenLockup", {
    from: deployer,
    args: [multiSig, startTimestamp, "0", "0", revocable],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })
  const { address: legalAddress } = await deploy("TokenLockup", {
    from: deployer,
    args: [multiSig, startTimestamp + 1, "0", "0", revocable],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })
  const { address: growthAddress } = await deploy("TokenLockup", {
    from: deployer,
    args: [multiSig, startTimestamp + 2, "0", "0", revocable],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })
  const { address: presaleAddress } = await deploy("TokenLockup", {
    from: deployer,
    args: [multiSig, startTimestamp + 3, "0", "0", revocable],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })
  const { address: founderAddress } = await deploy("TokenLockup", {
    from: deployer,
    args: [founderBeneficiaryAddress, startTimestamp + 4, "0", "0", revocable],
    log: true,
    deterministicDeployment: false,
    gasLimit: 5198000,
  })

  const lockup1 = await ethers.getContractAt("TokenLockup", lockupAddress1)
  await (await lockup1.transferOwnership(multiSig)).wait()

  const lockup2 = await ethers.getContractAt("TokenLockup", lockupAddress2)
  await (await lockup2.transferOwnership(multiSig)).wait()

  const fgcd = await ethers.getContractAt("TokenLockup", fgcdAddress)
  await (await fgcd.transferOwnership(multiSig)).wait()

  const legal = await ethers.getContractAt("TokenLockup", legalAddress)
  await (await legal.transferOwnership(multiSig)).wait()

  const growth = await ethers.getContractAt("TokenLockup", growthAddress)
  await (await growth.transferOwnership(multiSig)).wait()

  const presale = await ethers.getContractAt("TokenLockup", presaleAddress)
  await (await presale.transferOwnership(multiSig)).wait()

  const founder = await ethers.getContractAt("TokenLockup", founderAddress)
  await (await founder.transferOwnership(multiSig)).wait()

  const fate = await ethers.getContract("FateToken")
  const vault = await ethers.getContract("Vault")

  await (await fate.transfer(lockupAddress1, '30889346400000000000000000', { gasLimit: 5198000 })).wait()
  await (await fate.transfer(beneficiary1, '3432149600000000000000000', { gasLimit: 5198000 })).wait()
  await (await fate.transfer(lockupAddress2, '30889346400000000000000000', { gasLimit: 5198000 })).wait()
  await (await fate.transfer(beneficiary2, '3432149600000000000000000', { gasLimit: 5198000 })).wait()
  await (await fate.transfer(fgcdAddress, '36095600000000000000000000', { gasLimit: 5198000 })).wait() // 250,000 tokens are kept out of FGCD to fund initial FATE pool
  await (await fate.transfer(legalAddress, '8888888000000000000000000', { gasLimit: 5198000 })).wait()
  await (await fate.transfer(growthAddress, '530596436000000000000000000', { gasLimit: 5198000 })).wait()
  await (await fate.transfer(presaleAddress, '727272000000000000000000', { gasLimit: 5198000 })).wait()
  await (await fate.transfer(founderAddress, '88888888000000000000000000', { gasLimit: 5198000 })).wait()
  await (await fate.transfer(vault.address, '154798812000000000000000000', { gasLimit: 5198000 })).wait()
}

module.exports.tags = ["Timelock"]
module.exports.dependencies = ["FateToken", "Vault"]
