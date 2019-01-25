/* global artifacts */

const Marketplace = artifacts.require('Marketplace')
const MESGToken = artifacts.require('MESGToken')
const { asciiToHex } = require('../test/utils')

module.exports = async (deployer, network) => {
  await deployer.deploy(MESGToken, 'MESG Token', 'MESG', 18, 250000000)
  await deployer.deploy(Marketplace, MESGToken.address)

  if (network === 'staging') {
    const marketplace = await Marketplace.deployed()

    await marketplace.createService(asciiToHex('test-service-0'), 1000)
    console.log('service created')
    await marketplace.createServiceVersion(0, '0xa666c79d6eccdcdd670d25997b5ec7d3f7f8fc94', asciiToHex('https://raw.githubusercontent.com/mesg-foundation/marketplace/dev/metadata.json'))
    console.log('version created')
    await marketplace.createServiceVersion(0, '0xb444c79d6eccdcdd670d25997b5ec7d3f7f8fc94', asciiToHex('https://raw.githubusercontent.com/mesg-foundation/marketplace/dev/metadata.json'))
    console.log('version created')

    await marketplace.createService(asciiToHex('test-service-1'), 2000)
    console.log('service created')
    await marketplace.createServiceVersion(1, '0xc5555c79d6eccdcdd670d25997b5ec7d3f7f8fc94', asciiToHex('https://raw.githubusercontent.com/mesg-foundation/marketplace/dev/metadata.json'))
    console.log('version created')
  }
}
