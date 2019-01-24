/* global artifacts */

const Marketplace = artifacts.require('Marketplace')
const MESGToken = artifacts.require('MESGToken')

module.exports = async (deployer) => {
  await deployer.deploy(MESGToken, 'MESG Token', 'MESG', 18, 250000000)
  await deployer.deploy(Marketplace, MESGToken.address)
}
