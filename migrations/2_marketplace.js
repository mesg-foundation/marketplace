/* global artifacts */

const Marketplace = artifacts.require('Marketplace')
const MESGToken = artifacts.require('MESGToken')
const { asciiToHex } = require('web3-utils')

module.exports = async (deployer, network) => {
  switch (network) {
    case 'mainnet':
      break
    case 'ropsten':
      await deployer.deploy(Marketplace, process.env.MESG_MARKETPLACE_ROPSTEN_TOKEN_ADDRESS)
      break
    case 'kovan':
      break
    default:
      await deployer.deploy(MESGToken, 'MESG Token', 'MESG', 18, 250000000)
      await deployer.deploy(Marketplace, MESGToken.address)
  }

  if (network === 'staging') {
    const marketplace = await Marketplace.deployed()

    const sid = asciiToHex('test-service-0')
    const manifest = asciiToHex('QmfB1GtfjRQGFYAw3r9TKUjUyM3bY4cts9QXd16F8zDFDL')
    const manifestType = asciiToHex('ipfs')

    await marketplace.publishServiceVersion(sid, manifest, manifestType)
    console.log('service and version created')
    await marketplace.createServiceOffer(sid, 2 * 10e18, 60)
    console.log('offer created')
  }
}
