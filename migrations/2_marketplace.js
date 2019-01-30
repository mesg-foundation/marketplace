/* global artifacts */

const Marketplace = artifacts.require('Marketplace')
const MESGToken = artifacts.require('MESGToken')
const { asciiToHex } = require('../test/utils')

module.exports = async (deployer, network) => {
  await deployer.deploy(MESGToken, 'MESG Token', 'MESG', 18, 250000000)
  await deployer.deploy(Marketplace, MESGToken.address)

  if (network === 'staging') {
    const marketplace = await Marketplace.deployed()

    const sid = asciiToHex('test-service-0')
    const sid2 = asciiToHex('test-service-1')
    const metadata = asciiToHex('https://raw.githubusercontent.com/mesg-foundation/marketplace/dev/metadata.json')

    await marketplace.createService(sid)
    console.log('service created')
    await marketplace.createServiceVersion(sid, '0xa666c79d6eccdcdd670d25997b5ec7d3f7f8fc94', metadata)
    console.log('version created')
    await marketplace.createServiceVersion(sid, '0xb444c79d6eccdcdd670d25997b5ec7d3f7f8fc94', metadata)
    console.log('version created')
    await marketplace.createServiceOffer(sid, 100, 60)
    console.log('offer created')
    await marketplace.createServiceOffer(sid, 1000, 3600 * 24)
    console.log('offer created')

    await marketplace.createService(sid2)
    console.log('service created')
    await marketplace.createServiceVersion(sid2, '0xc5555c79d6eccdcdd670d25997b5ec7d3f7f8fc94', metadata)
    console.log('version created')
    await marketplace.createServiceOffer(sid2, 2000, 3600 * 24)
    console.log('offer created')
  }
}
