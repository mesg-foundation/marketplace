/* eslint-env mocha */
/* global contract, artifacts, web3 */
const assert = require('chai').assert
const { asciiToHex, padRight, toBN, sha3 } = require('web3-utils')
const truffleAssert = require('truffle-assertions')

const Marketplace = artifacts.require('Marketplace')
const Token = artifacts.require('MESGToken')

// useful shortcut and constant
const padRight64 = x => padRight(x, 64)
const sleep = sec => new Promise(resolve => setTimeout(resolve, sec * 1000))
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
const ZERO_HASH = '0x0000000000000000000000000000000000000000000000000000000000000000'
const INFINITY = toBN('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')

// contracts object
let token = null
let marketplace = null

// errors
const errors = {
  whenAddressNotZero: 'Address cannot be set to zero',
  whenServiceExist: 'Service with this sid does not exist',
  whenServiceNotExist: 'Service with same sid already exists',
  onlyServiceOwner: 'Service owner is not the sender',
  notServiceOwner: 'Service owner cannot be the sender',
  whenServiceHashNotExist: 'Hash already exists',
  whenServiceVersionNotEmpty: 'Cannot create an offer on a service without version',
  whenServiceOfferExist: 'Service offer does not exist',
  whenServiceOfferActive: 'Service offer is not active',
  whenSidNotEmpty: 'Sid cannot be empty',
  whenSidTooLong: 'Sid cannot exceed 63 chars',
  whenManifestNotEmpty: 'Manifest cannot be empty',
  whenManifestProtocolNotEmpty: 'Manifest protocol cannot be empty',
  whenDurationNotZero: 'Duration cannot be zero',
  senderNotEnoughBalance: 'Sender does not have enough balance to pay this service',
  senderDidNotApprove: 'Sender did not approve this contract to spend on his behalf. Execute approve function on the token contract'
}

// constants used for creating services, versions and offers
const sidNames = [
  asciiToHex('test-service-0'),
  asciiToHex('test-service-1')
]

const sids = [
  sha3('test-service-0'),
  sha3('test-service-1')
]

const versions = [
  {
    hash: '0x0000000000000000000000000000000000000000000000000000000000000001',
    manifest: asciiToHex('QmarHSr9aSNaPSR6G9KFPbuLV9aEqJfTk1y9B8pdwqK4Rq'),
    manifestProtocol: asciiToHex('ipfs')
  },
  {
    hash: '0x0000000000000000000000000000000000000000000000000000000000000002',
    manifest: asciiToHex('https://mesg.com/download/v2/core.tar'),
    manifestProtocol: asciiToHex('https')
  }
]

const offers = [
  {
    price: 1000,
    duration: 1
  },
  {
    price: 2000,
    duration: 2
  },
  {
    price: 3000,
    duration: INFINITY
  }
]

const initTokenBalance = 10e3

contract('Marketplace', async ([ owner, ...accounts ]) => {
  before(async () => {
    token = await Token.new('MESG', 'MESG', 18, 25 * 10e6, { from: owner })
    marketplace = await Marketplace.new(token.address, { from: owner })
  })

  describe('contract', async () => {
    it('inherit Ownable', async () => {
      assert.isTrue(await marketplace.isOwner({ from: owner }))
    })
    it('inherit Pausable', async () => {
      assert.isTrue(await marketplace.isPauser(owner))
    })
    it('service list must be empty on creation', async () => {
      assert.equal(await marketplace.servicesListLength(), 0)
    })
  })
})

contract('Marketplace', async ([ owner, ...accounts ]) => {
  before(async () => {
    token = await Token.new('MESG', 'MESG', 18, 25 * 10e6, { from: owner })
    marketplace = await Marketplace.new(token.address, { from: owner })
    await token.transfer(accounts[1], initTokenBalance, { from: owner })
  })

  describe('emit event', async () => {
    it('ServiceCreated', async () => {
      const tx = await marketplace.createService(sidNames[0], { from: accounts[0] })
      truffleAssert.eventEmitted(tx, 'ServiceCreated')
      const event = tx.logs[0].args
      assert.equal(event.sid, padRight64(sids[0]))
      assert.equal(event.owner, accounts[0])
    })
    it('ServiceVersionCreated', async () => {
      const tx = await marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].manifest, versions[0].manifestProtocol, { from: accounts[0] })
      truffleAssert.eventEmitted(tx, 'ServiceVersionCreated')
      const event = tx.logs[0].args
      assert.equal(event.sid, padRight64(sids[0]))
      assert.equal(event.hash, padRight64(versions[0].hash))
      assert.equal(event.manifest, versions[0].manifest)
      assert.equal(event.manifestProtocol, versions[0].manifestProtocol)
    })
    it('ServiceOfferCreated', async () => {
      const tx = await marketplace.createServiceOffer(sids[0], offers[0].price, offers[0].duration, { from: accounts[0] })
      truffleAssert.eventEmitted(tx, 'ServiceOfferCreated')
      const event = tx.logs[0].args
      assert.equal(event.sid, padRight64(sids[0]))
      assert.equal(event.price, offers[0].price)
      assert.equal(event.duration, offers[0].duration)
      assert.equal(event.offerIndex, 0)
    })
    it('ServicePurchased', async () => {
      await token.approve(marketplace.address, offers[0].price, { from: accounts[1] })
      const tx = await marketplace.purchase(sids[0], 0, { from: accounts[1] })
      const block = await web3.eth.getBlock(tx.receipt.blockHash)
      truffleAssert.eventEmitted(tx, 'ServicePurchased')
      const event = tx.logs[0].args
      assert.equal(event.sid, padRight64(sids[0]))
      assert.equal(event.offerIndex, 0)
      assert.equal(event.purchaser, accounts[1])
      assert.equal(event.price, offers[0].price)
      assert.equal(event.duration, offers[0].duration)
      assert.equal(event.expire, block.timestamp + offers[0].duration)
    })
    it('ServiceOfferDisabled', async () => {
      const tx = await marketplace.disableServiceOffer(sids[0], 0, { from: accounts[0] })
      truffleAssert.eventEmitted(tx, 'ServiceOfferDisabled')
      const event = tx.logs[0].args
      assert.equal(event.sid, padRight64(sids[0]))
      assert.equal(event.offerIndex, 0)
    })
    it('ServiceOwnershipTransferred', async () => {
      const tx = await marketplace.transferServiceOwnership(sids[0], accounts[1], { from: accounts[0] })
      truffleAssert.eventEmitted(tx, 'ServiceOwnershipTransferred')
      const event = tx.logs[0].args
      assert.equal(event.sid, padRight64(sids[0]))
      assert.equal(event.previousOwner, accounts[0])
      assert.equal(event.newOwner, accounts[1])
    })
  })
})

contract('Marketplace', async ([ owner, ...accounts ]) => {
  before(async () => {
    token = await Token.new('MESG', 'MESG', 18, 25 * 10e6, { from: owner })
    marketplace = await Marketplace.new(token.address, { from: owner })
    await marketplace.pause({ from: owner })
  })

  describe('set pause', async () => {
    it('createService', async () => {
      await truffleAssert.reverts(marketplace.createService(sidNames[0], { from: accounts[0] }))
    })
    it('transferServiceOwnership', async () => {
      await truffleAssert.reverts(marketplace.transferServiceOwnership(sids[0], accounts[1], { from: accounts[0] }))
    })
    it('createServiceVersion', async () => {
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].manifest, versions[0].manifestProtocol, { from: accounts[0] }))
    })
    it('createServiceOffer', async () => {
      await truffleAssert.reverts(marketplace.createServiceOffer(sids[0], offers[0].price, offers[0].duration, { from: accounts[0] }))
    })
    it('disableServiceOffer', async () => {
      await truffleAssert.reverts(marketplace.disableServiceOffer(sids[0], 0, { from: accounts[0] }))
    })
    it('purchase', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[0], 0, { from: accounts[0] }))
    })
  })
})

contract('Marketplace', async ([ owner, ...accounts ]) => {
  before(async () => {
    token = await Token.new('MESG', 'MESG', 18, 25 * 10e6, { from: owner })
    marketplace = await Marketplace.new(token.address, { from: owner })
  })

  describe('service create', async () => {
    it('should return 0x0 address on getting service with non existing sids[0]', async () => {
      assert.equal(await marketplace.services(sids[0]), 0)
    })
    it('should create service', async () => {
      await marketplace.createService(sidNames[0], { from: accounts[0] })
    })
    it('should have one service', async () => {
      assert.equal(await marketplace.servicesListLength(), 1)
      assert.equal(await marketplace.services(sids[0]), accounts[0])
    })
    it('should fail when create with empty sid', async () => {
      await truffleAssert.reverts(marketplace.createService('0x', { from: accounts[0] }), errors.whenSidNotEmpty)
    })
    it('should fail when create with existing sids[0]', async () => {
      await truffleAssert.reverts(marketplace.createService(sidNames[0], { from: accounts[0] }), errors.whenServiceNotExist)
    })
    it('should fail when sid is too long', async () => {
      await truffleAssert.reverts(marketplace.createService(asciiToHex('a'.repeat(64)), { from: accounts[0] }), errors.whenSidTooLong)
    })
    it('should create 2nd service', async () => {
      await marketplace.createService(sidNames[1], { from: accounts[0] })
    })
    it('should have two services', async () => {
      assert.equal(await marketplace.servicesListLength(), 2)
      assert.equal(await marketplace.services(sids[1]), accounts[0])
    })
    it('should create service with valid names', async () => {
      await marketplace.createService(asciiToHex('abcdefghijklmnopqrstuvwxyz'), { from: accounts[0] })
      await marketplace.createService(asciiToHex('_1234567890'), { from: accounts[0] })
      await marketplace.createService(asciiToHex('service'), { from: accounts[0] })
      await marketplace.createService(asciiToHex('service.mesg'), { from: accounts[0] })
      await marketplace.createService(asciiToHex('service-0.mesg'), { from: accounts[0] })
      await marketplace.createService(asciiToHex('_service.mesg'), { from: accounts[0] })
      await marketplace.createService(asciiToHex('1-service.mesg'), { from: accounts[0] })
      await marketplace.createService(asciiToHex('core.service.mesg'), { from: accounts[0] })
    })
  })
})

contract('Marketplace', async ([ owner, ...accounts ]) => {
  before(async () => {
    token = await Token.new('MESG', 'MESG', 18, 25 * 10e6, { from: owner })
    marketplace = await Marketplace.new(token.address, { from: owner })
    await marketplace.createService(sidNames[0], { from: accounts[0] })
  })

  describe('service ownership', async () => {
    it('should fail when service doesn\'t exist', async () => {
      await truffleAssert.reverts(marketplace.transferServiceOwnership(asciiToHex('-'), accounts[0], { from: accounts[0] }), errors.onlyServiceOwner)
    })
    it('should fail when new owner address equals 0x0', async () => {
      await truffleAssert.reverts(marketplace.transferServiceOwnership(sids[0], ZERO_ADDRESS, { from: accounts[0] }), errors.whenAddressNotZero)
    })
    it('should fail when called by not owner', async () => {
      await truffleAssert.reverts(marketplace.transferServiceOwnership(sids[0], accounts[1], { from: accounts[1] }), errors.onlyServiceOwner)
    })
    it('should transfer', async () => {
      await marketplace.transferServiceOwnership(sids[0], accounts[1], { from: accounts[0] })
    })
  })
})

contract('Marketplace', async ([ owner, ...accounts ]) => {
  before(async () => {
    token = await Token.new('MESG', 'MESG', 18, 25 * 10e6, { from: owner })
    marketplace = await Marketplace.new(token.address, { from: owner })
    await marketplace.createService(sidNames[0], { from: accounts[0] })
  })

  describe('service versions', async () => {
    it('should not have any version', async () => {
      assert.equal(await marketplace.servicesVersionsListLength(sids[0]), 0)
    })
    it('should fail not service owner', async () => {
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].manifest, versions[0].manifestProtocol, { from: accounts[1] }), errors.onlyServiceOwner)
    })
    it('should fail hash is too long', async () => {
      await truffleAssert.fails(marketplace.createServiceVersion(sids[0], ZERO_HASH + '1', versions[0].manifest, versions[0].manifestProtocol, { from: accounts[0] }))
    })
    it('should fail get version list count - service not exist', async () => {
      await truffleAssert.reverts(marketplace.servicesVersionsListLength(sids[1]), errors.whenServiceExist)
    })
    it('should fail get version list item - service not exist', async () => {
      await truffleAssert.reverts(marketplace.servicesVersionsList(sids[1], 0), errors.whenServiceExist)
    })
    it('should fail get version - service not exist', async () => {
      await truffleAssert.reverts(marketplace.servicesVersion(sids[1], versions[0].hash), errors.whenServiceExist)
    })
    it('should fail manifest empty', async () => {
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, '0x00', versions[0].manifestProtocol, { from: accounts[0] }), errors.whenManifestNotEmpty)
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, '0x0000', versions[0].manifestProtocol, { from: accounts[0] }), errors.whenManifestNotEmpty)
    })
    it('should fail manifest protocol empty', async () => {
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].manifest, '0x00', { from: accounts[0] }), errors.whenManifestProtocolNotEmpty)
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].manifest, '0x00', { from: accounts[0] }), errors.whenManifestProtocolNotEmpty)
    })
    it('should create service version', async () => {
      await marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].manifest, versions[0].manifestProtocol, { from: accounts[0] })
    })
    it('should fail create service with existing version', async () => {
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].manifest, versions[0].manifestProtocol, { from: accounts[0] }), errors.whenServiceHashNotExist)
    })
    it('should have one service version', async () => {
      assert.equal(await marketplace.servicesVersionsListLength(sids[0]), 1)
      const version = await marketplace.servicesVersion(sids[0], versions[0].hash)
      assert.equal(version.manifest, versions[0].manifest)
      assert.equal(version.manifestProtocol, versions[0].manifestProtocol)
      assert.equal(await marketplace.servicesVersionsList(sids[0], 0), versions[0].hash)
    })
    it('should create 2nd service version', async () => {
      await marketplace.createServiceVersion(sids[0], versions[1].hash, versions[1].manifest, versions[1].manifestProtocol, { from: accounts[0] })
    })
    it('should have two service versions', async () => {
      assert.equal(await marketplace.servicesVersionsListLength(sids[0]), 2)
      const version = await marketplace.servicesVersion(sids[0], versions[1].hash)
      assert.equal(version.manifest, versions[1].manifest)
      assert.equal(version.manifestProtocol, versions[1].manifestProtocol)
      assert.equal(await marketplace.servicesVersionsList(sids[0], 1), versions[1].hash)
    })
  })
})

contract('Marketplace', async ([ owner, ...accounts ]) => {
  before(async () => {
    token = await Token.new('MESG', 'MESG', 18, 25 * 10e6, { from: owner })
    marketplace = await Marketplace.new(token.address, { from: owner })
    await marketplace.createService(sidNames[0], { from: accounts[0] })
  })

  describe('service offers', async () => {
    it('should not have any offer', async () => {
      assert.equal(await marketplace.servicesOffersLength(sids[0]), 0)
    })
    it('should fail not service owner', async () => {
      await truffleAssert.reverts(marketplace.createServiceOffer(sids[0], offers[0].price, offers[0].duration, { from: accounts[1] }), errors.onlyServiceOwner)
    })
    it('should fail get offers count - service not exist', async () => {
      await truffleAssert.reverts(marketplace.servicesOffersLength(sids[1]), errors.whenServiceExist)
    })
    it('should fail get offer - service not exist', async () => {
      await truffleAssert.reverts(marketplace.servicesOffer(sids[1], 0), errors.whenServiceExist)
    })
    it('should fail create service offer without version', async () => {
      await truffleAssert.reverts(marketplace.createServiceOffer(sids[0], offers[0].price, offers[0].duration, { from: accounts[0] }), errors.whenServiceVersionNotEmpty)
    })
    it('should create service version', async () => {
      await marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].manifest, versions[0].manifestProtocol, { from: accounts[0] })
    })
    it('should fail duration is 0', async () => {
      await truffleAssert.reverts(marketplace.createServiceOffer(sids[0], offers[0].price, 0, { from: accounts[0] }), errors.whenDurationNotZero)
    })
    it('should create service offer', async () => {
      await marketplace.createServiceOffer(sids[0], offers[0].price, offers[0].duration, { from: accounts[0] })
    })
    it('should have one service offer', async () => {
      assert.equal(await marketplace.servicesOffersLength(sids[0]), 1)
      const offer = await marketplace.servicesOffer(sids[0], 0)
      assert.equal(offer.price, offers[0].price)
      assert.equal(offer.duration, offers[0].duration)
      assert.isTrue(offer.active)
    })
    it('should create 2nd service version', async () => {
      await marketplace.createServiceOffer(sids[0], offers[1].price, offers[1].duration, { from: accounts[0] })
    })
    it('should have two service offers', async () => {
      assert.equal(await marketplace.servicesOffersLength(sids[0]), 2)
      const offer = await marketplace.servicesOffer(sids[0], 1)
      assert.equal(offer.price, offers[1].price)
      assert.equal(offer.duration, offers[1].duration)
      assert.isTrue(offer.active)
    })
    it('should fail - disable service offer only owner', async () => {
      await truffleAssert.reverts(marketplace.disableServiceOffer(sids[0], 0, { from: accounts[1] }), errors.onlyServiceOwner)
    })
    it('should fail - disable service offer not exist', async () => {
      await truffleAssert.reverts(marketplace.disableServiceOffer(sids[0], 2, { from: accounts[0] }), errors.whenServiceOfferExist)
    })
    it('should disable service offer', async () => {
      await marketplace.disableServiceOffer(sids[0], 0, { from: accounts[0] })
    })
    it('should service offer be disabled', async () => {
      const offer = await marketplace.servicesOffer(sids[0], 0)
      assert.isFalse(offer.active)
    })
    it('should create service offer with duration set to infinity', async () => {
      await marketplace.createServiceOffer(sids[0], offers[2].price, offers[2].duration, { from: accounts[0] })
    })
  })
})

contract('Marketplace', async ([ owner, ...accounts ]) => {
  before(async () => {
    token = await Token.new('MESG', 'MESG', 18, 25 * 10e6, { from: owner })
    marketplace = await Marketplace.new(token.address, { from: owner })
    await marketplace.createService(sidNames[0], { from: accounts[0] })
    await marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].manifest, versions[0].manifestProtocol, { from: accounts[0] })
    await marketplace.createServiceOffer(sids[0], offers[0].price, offers[0].duration, { from: accounts[0] })
    await marketplace.createServiceOffer(sids[0], offers[1].price, offers[1].duration, { from: accounts[0] })
    await marketplace.createServiceOffer(sids[0], offers[2].price, offers[2].duration, { from: accounts[0] })
  })

  describe('service purchase', async () => {
    it('should not have any purchases', async () => {
      assert.equal(await marketplace.servicesPurchasesListLength(sids[0]), 0)
    })
    it('should fail get purchases list count - service not exist', async () => {
      await truffleAssert.reverts(marketplace.servicesPurchasesListLength(sids[1]), errors.whenServiceExist)
    })
    it('should fail get purchases list item - service not exist', async () => {
      await truffleAssert.reverts(marketplace.servicesPurchasesList(sids[1], 0), errors.whenServiceExist)
    })
    it('should fail get purchases - service not exist', async () => {
      await truffleAssert.reverts(marketplace.servicesPurchase(sids[1], accounts[0]), errors.whenServiceExist)
    })
    it('should get purchases return 0', async () => {
      assert.equal(await marketplace.servicesPurchase(sids[0], accounts[0]), 0)
    })
    it('should has purchased return true for service owner', async () => {
      assert.isTrue(await marketplace.isAuthorized(sids[0], { from: accounts[0] }))
    })
    it('should has purchased return false', async () => {
      assert.isFalse(await marketplace.isAuthorized(sids[0], { from: accounts[1] }))
    })
    it('should fail purchase - service not exist', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[1], 0, { from: accounts[0] }), errors.whenServiceExist)
    })
    it('should fail purchase - service offer not exist', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[0], 10, { from: owner }), errors.whenServiceOfferExist)
    })
    it('should fail purchase - service owner can\'t buy', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[0], 0, { from: accounts[0] }), errors.notServiceOwner)
    })
    it('should fail purchase - balance < offer.price', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[0], 0, { from: accounts[1] }), errors.senderNotEnoughBalance)
    })
    it('should transfer tokens', async () => {
      await token.transfer(accounts[1], initTokenBalance, { from: owner })
      await token.transfer(accounts[2], initTokenBalance, { from: owner })
    })
    it('should fail purchase - sender not approve', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[0], 0, { from: accounts[1] }), errors.senderDidNotApprove)
    })
    it('should purchase service offer', async () => {
      await token.approve(marketplace.address, offers[0].price, { from: accounts[1] })
      const tx = await marketplace.purchase(sids[0], 0, { from: accounts[1] })
      const block = await web3.eth.getBlock(tx.receipt.blockHash)

      assert.equal(await marketplace.servicesPurchasesListLength(sids[0]), 1)
      assert.equal(await marketplace.servicesPurchasesList(sids[0], 0), accounts[1])
      assert.isTrue(await marketplace.isAuthorized(sids[0], { from: accounts[1] }))

      const expire = await marketplace.servicesPurchase(sids[0], accounts[1])
      assert.equal(expire, block.timestamp + offers[0].duration)
    })
    it('should purchased service expire', async () => {
      await sleep(offers[0].duration + 1)
      assert.isFalse(await marketplace.isAuthorized(sids[0], { from: accounts[1] }))
    })
    it('should transfer token to service owner after purchase', async () => {
      assert.equal(await token.balanceOf(accounts[0]), offers[0].price)
      assert.equal(await token.balanceOf(accounts[1]), initTokenBalance - offers[0].price)
    })
    it('should purchase service offer with 2nd account', async () => {
      await token.approve(marketplace.address, offers[0].price, { from: accounts[2] })
      await marketplace.purchase(sids[0], 0, { from: accounts[2] })
      assert.equal(await marketplace.servicesPurchasesListLength(sids[0]), 2)
      assert.isTrue(await marketplace.isAuthorized(sids[0], { from: accounts[2] }))
    })
    it('should disable service offer', async () => {
      await marketplace.disableServiceOffer(sids[0], 0, { from: accounts[0] })
    })
    it('should fail purchase - service offer not active', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[0], 0), errors.whenServiceOfferActive)
    })
    it('should purchase service offer twice', async () => {
      await token.approve(marketplace.address, 2 * offers[1].price, { from: accounts[1] })
      const tx = await marketplace.purchase(sids[0], 1, { from: accounts[1] })
      await marketplace.purchase(sids[0], 1, { from: accounts[1] })
      const block = await web3.eth.getBlock(tx.receipt.blockHash)

      assert.equal(await marketplace.servicesPurchasesListLength(sids[0]), 2)
      assert.equal(await marketplace.servicesPurchasesList(sids[0], 0), accounts[1])

      const expire = await marketplace.servicesPurchase(sids[0], accounts[1])
      assert.equal(expire, block.timestamp + 2 * offers[1].duration)
    })
    it('should purchase service with infinity offer', async () => {
      await token.approve(marketplace.address, offers[2].price, { from: accounts[1] })
      await marketplace.purchase(sids[0], 2, { from: accounts[1] })
      const expire = await marketplace.servicesPurchase(sids[0], accounts[1])
      assert.equal(expire.cmp(INFINITY), 0)
    })
    it('should purchase service with infinity expire not emit event', async () => {
      await token.approve(marketplace.address, offers[2].price, { from: accounts[1] })
      const tx = await marketplace.purchase(sids[0], 2, { from: accounts[1] })
      truffleAssert.eventNotEmitted(tx, 'ServicePurchased')
    })
    it('should transfer service', async () => {
      await marketplace.transferServiceOwnership(sids[0], accounts[1], { from: accounts[0] })
    })
    it('should has purchased return true for new service owner', async () => {
      assert.isTrue(await marketplace.isAuthorized(sids[0], { from: accounts[1] }))
    })
    it('should has purchased return false for previous service owner', async () => {
      assert.isTrue(await marketplace.isAuthorized(sids[0], accounts[0], { from: accounts[1] }))
    })
  })
})
