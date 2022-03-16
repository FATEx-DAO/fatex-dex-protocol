module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy } = deployments
  
    const { deployer } = await getNamedAccounts()
  
    const { address } = await deploy("MockLpTokenFactory", {
      from: deployer,
      args: [],
      log: true,
      deterministicDeployment: false,
      gasLimit: 5198000,
    })
  
    console.log(`MockLpTokenFactory deployed at ${address}`)
  }
  
  module.exports.tags = ["MockLpTokenFactory"]
  