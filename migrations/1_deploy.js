var Marketplace = artifacts.require("./Marketplace.sol")
var Payment = artifacts.require("./Payment.sol")

module.exports = async (deployer) => {
  await deployer.deploy(Marketplace)
  await deployer.deploy(Payment)

  // need to set Payment.address to Marketplace
}
