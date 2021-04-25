
module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
    const { deploy } = deployments

    const { deployer } = await getNamedAccounts()

    const { address } = await deploy("StrategistProfiter", {
      from: deployer,
      args: [],
      log: true,
      deterministicDeployment: false
    })

  }

  module.exports.tags = ["StrategistProfiter"]
