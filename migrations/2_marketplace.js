/* global artifacts */

const Marketplace = artifacts.require('./Marketplace.sol')

module.exports = async (deployer) => {
  await deployer.deploy(Marketplace)
}
