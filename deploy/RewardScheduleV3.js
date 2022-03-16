module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy } = deployments
  
    const { deployer } = await getNamedAccounts()

    const epochStartBlock = 18575540 // should be set with proper data
    const lockedPercent = '920000000000000000' // 92%
  
    const { address } = await deploy("RewardScheduleV3", {
      from: deployer,
      args: [epochStartBlock, lockedPercent],
      log: true,
      deterministicDeployment: false,
      gasLimit: 5198000,
    })

    console.log('RewardScheduleV3 deployed addresss: ', address)
  }
  
  module.exports.tags = ["RewardScheduleV3"]
  
  