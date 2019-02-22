/* eslint-env mocha */
/* global contract, artifacts, web3 */
const assert = require('chai').assert
const { asciiToHex, padRight, toBN } = require('web3-utils')
const truffleAssert = require('truffle-assertions')

const Marketplace = artifacts.require('Marketplace')
const Token = artifacts.require('MESGToken')

// useful shortcut and constant
const sleep = sec => new Promise(resolve => setTimeout(resolve, sec * 1000))
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
const ZERO_HASH = '0x0000000000000000000000000000000000000000000000000000000000000000'
const INFINITY = toBN('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')

// contracts object
let token = null
let marketplace = null

// errors
const errors = {
  ERR_ADDRESS_ZERO: "address is zero",

  ERR_SID_LEN: "sid must be between 1 and 63 characters",
  ERR_SID_INVALID: "sid must be a valid dns name",

  ERR_SERVICE_EXIST: "service with given sid already exists",
  ERR_SERVICE_NOT_EXIST: "service with given sid does not exist",
  ERR_SERVICE_NOT_OWNER: "sender is not the service owner",

  ERR_VERSION_EXIST: "version with given hash already exists",
  ERR_VERSION_MANIFEST_LEN: "version manifest must have at least 1 character",
  ERR_VERSION_MANIFEST_PROTOCOL_LEN: "version manifest protocol must have at least 1 character",

  ERR_OFFER_NOT_EXIST: "offer dose not exist",
  ERR_OFFER_NO_VERSION: "offer must be created with at least 1 version",
  ERR_OFFER_NOT_ACTIVE: "offer must be active",
  ERR_OFFER_DURATION_MIN: "offer duration must be grather then 0",

  ERR_PURCHASE_OWNER: "sender cannot purchase his own service",
  ERR_PURCHASE_INFINITY: "service already purchase for infinity",
  ERR_PURCHASE_TOKEN_BALANCE: "token balance must be grather to purchase the service",
  ERR_PURCHASE_TOKEN_APPROVE: "sender must approve the marketplace to spend token",
}

// constants used for creating services, versions and offers
const sids = [
  asciiToHex('test-service-0', 0),
  asciiToHex('test-service-1', 0),
  asciiToHex('test-service-2', 0)
]

const versions = [
  {
    hash: '0x0000000000000000000000000000000000000000000000000000000000000001',
    manifest: asciiToHex('QmarHSr9aSNaPSR6G9KFPbuLV9aEqJfTk1y9B8pdwqK4Rq', 0),
    manifestProtocol: asciiToHex('ipfs', 0)
  },
  {
    hash: '0x0000000000000000000000000000000000000000000000000000000000000002',
    manifest: asciiToHex('https://mesg.com/download/v2/core.tar', 0),
    manifestProtocol: asciiToHex('https', 0)
  },
  {
    hash: '0x0000000000000000000000000000000000000000000000000000000000000003',
    manifest: asciiToHex('https://mesg.com/download/v3/core.tar', 0),
    manifestProtocol: asciiToHex('https', 0)
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
  },
  {
    price: 4000,
    duration: 4
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
      assert.equal(await marketplace.servicesLength(), 0)
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
      const tx = await marketplace.createService(sids[0], { from: accounts[0] })
      truffleAssert.eventEmitted(tx, 'ServiceCreated')
      const event = tx.logs[0].args
      assert.equal(event.sid, sids[0])
      assert.equal(event.owner, accounts[0])
    })
    it('ServiceVersionCreated', async () => {
      const tx = await marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].manifest, versions[0].manifestProtocol, { from: accounts[0] })
      truffleAssert.eventEmitted(tx, 'ServiceVersionCreated')
      const event = tx.logs[0].args
      assert.equal(event.sid, sids[0])
      assert.equal(event.hash, padRight(versions[0].hash, 64))
      assert.equal(event.manifest, versions[0].manifest)
      assert.equal(event.manifestProtocol, versions[0].manifestProtocol)
    })
    it('ServiceOfferCreated', async () => {
      const tx = await marketplace.createServiceOffer(sids[0], offers[0].price, offers[0].duration, { from: accounts[0] })
      truffleAssert.eventEmitted(tx, 'ServiceOfferCreated')
      const event = tx.logs[0].args
      assert.equal(event.sid, sids[0])
      assert.equal(event.price, offers[0].price)
      assert.equal(event.duration, offers[0].duration)
      assert.equal(event.index, 0)
    })
    it('ServicePurchased', async () => {
      await token.approve(marketplace.address, offers[0].price, { from: accounts[1] })
      const tx = await marketplace.purchase(sids[0], 0, { from: accounts[1] })
      const block = await web3.eth.getBlock(tx.receipt.blockHash)
      truffleAssert.eventEmitted(tx, 'ServicePurchased')
      const event = tx.logs[0].args
      assert.equal(event.sid, sids[0])
      assert.equal(event.index, 0)
      assert.equal(event.purchaser, accounts[1])
      assert.equal(event.price, offers[0].price)
      assert.equal(event.duration, offers[0].duration)
      assert.equal(event.expire, block.timestamp + offers[0].duration)
    })
    it('ServiceOfferDisabled', async () => {
      const tx = await marketplace.disableServiceOffer(sids[0], 0, { from: accounts[0] })
      truffleAssert.eventEmitted(tx, 'ServiceOfferDisabled')
      const event = tx.logs[0].args
      assert.equal(event.sid, sids[0])
      assert.equal(event.index, 0)
    })
    it('ServiceOwnershipTransferred', async () => {
      const tx = await marketplace.transferServiceOwnership(sids[0], accounts[1], { from: accounts[0] })
      truffleAssert.eventEmitted(tx, 'ServiceOwnershipTransferred')
      const event = tx.logs[0].args
      assert.equal(event.sid, sids[0])
      assert.equal(event.previousOwner, accounts[0])
      assert.equal(event.newOwner, accounts[1])
    })
    it('publishServiceVersion', async () => {
      const tx = await marketplace.publishServiceVersion(sids[1], versions[1].hash, versions[1].manifest, versions[1].manifestProtocol, { from: accounts[0] })
      truffleAssert.eventEmitted(tx, 'ServiceCreated')
      truffleAssert.eventEmitted(tx, 'ServiceVersionCreated')

      const createEvent = tx.logs[0].args
      assert.equal(createEvent.sid, sids[1])
      assert.equal(createEvent.owner, accounts[0])

      const createVersionEvent = tx.logs[1].args
      assert.equal(createVersionEvent .sid, sids[1])
      assert.equal(createVersionEvent .hash, padRight(versions[1].hash, 64))
      assert.equal(createVersionEvent .manifest, versions[1].manifest)
      assert.equal(createVersionEvent .manifestProtocol, versions[1].manifestProtocol)
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
      await truffleAssert.reverts(marketplace.createService(sids[0], { from: accounts[0] }))
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
    it('service should not exist', async () => {
      const service = await marketplace.service(sids[0])
      assert.equal(service.owner, 0)
      assert.isNull(service.sid)
      assert.isFalse(await marketplace.isServiceExist(sids[0]))
    })
    it('should create service', async () => {
      await marketplace.createService(sids[0], { from: accounts[0] })
    })
    it('should have one service', async () => {
      assert.equal(await marketplace.servicesLength(), 1)
      assert.isTrue(await marketplace.isServiceExist(sids[0]))
      const service = await marketplace.service(sids[0])
      assert.equal(service.owner, accounts[0])
      assert.equal(service.sid, sids[0])
      assert.equal(service.sid, sids[0])
    })
    it('should fail when create with empty sid', async () => {
      await truffleAssert.reverts(marketplace.createService('0x', { from: accounts[0] }), errors.ERR_SID_LEN)
    })
    it('should fail when create with existing sid', async () => {
      await truffleAssert.reverts(marketplace.createService(sids[0], { from: accounts[0] }), errors.ERR_SERVICE_EXIST)
    })
    it('should fail when sid is too long', async () => {
      await truffleAssert.reverts(marketplace.createService(asciiToHex('a'.repeat(64)), { from: accounts[0] }), errors.ERR_SID_LEN)
    })
    it('should create 2nd service', async () => {
      await marketplace.createService(sids[1], { from: accounts[0] })
    })
    it('should have two services', async () => {
      assert.equal(await marketplace.servicesLength(), 2)
      assert.isTrue(await marketplace.isServiceExist(sids[1]))
      const service = await marketplace.service(sids[1])
      assert.equal(service.owner, accounts[0])
      assert.equal(service.sid, sids[1])
    })
    it('should create service with valid names', async () => {
      await marketplace.createService(asciiToHex('abcdefghijklmnopqrstuvwxyz', 0), { from: accounts[0] })
      await marketplace.createService(asciiToHex('_1234567890', 0), { from: accounts[0] })
      await marketplace.createService(asciiToHex('service', 0), { from: accounts[0] })
      await marketplace.createService(asciiToHex('service.mesg', 0), { from: accounts[0] })
      await marketplace.createService(asciiToHex('service-0.mesg', 0), { from: accounts[0] })
      await marketplace.createService(asciiToHex('_service.mesg', 0), { from: accounts[0] })
      await marketplace.createService(asciiToHex('1-service.mesg', 0), { from: accounts[0] })
      await marketplace.createService(asciiToHex('core.service.mesg', 0), { from: accounts[0] })
      await truffleAssert.reverts(marketplace.createService(asciiToHex('-service', 0), { from: accounts[0] }), errors.ERR_SID_INVALID)
      await truffleAssert.reverts(marketplace.createService(asciiToHex('service-', 0), { from: accounts[0] }), errors.ERR_SID_INVALID)
      await truffleAssert.reverts(marketplace.createService(asciiToHex('.service', 0), { from: accounts[0] }), errors.ERR_SID_INVALID)
      await truffleAssert.reverts(marketplace.createService(asciiToHex('s..ervice', 0), { from: accounts[0] }), errors.ERR_SID_INVALID)
    })
    it('should set create time', async () => {
      const tx = await marketplace.createService(sids[2], { from: accounts[0] })
      const block = await web3.eth.getBlock(tx.receipt.blockHash)
      const service = await marketplace.service(sids[2])
      assert.equal(service.createTime, block.timestamp)
    })
  })
})

contract('Marketplace', async ([ owner, ...accounts ]) => {
  before(async () => {
    token = await Token.new('MESG', 'MESG', 18, 25 * 10e6, { from: owner })
    marketplace = await Marketplace.new(token.address, { from: owner })
    await marketplace.createService(sids[0], { from: accounts[0] })
  })

  describe('service ownership', async () => {
    it('should fail when service doesn\'t exist', async () => {
      await truffleAssert.reverts(marketplace.transferServiceOwnership(asciiToHex('-', 0), accounts[0], { from: accounts[0] }), errors.ERR_SERVICE_NOT_OWNER)
    })
    it('should fail when new owner address equals 0x0', async () => {
      await truffleAssert.reverts(marketplace.transferServiceOwnership(sids[0], ZERO_ADDRESS, { from: accounts[0] }), errors.ERR_ADDRESS_ZERO)
    })
    it('should fail when called by not owner', async () => {
      await truffleAssert.reverts(marketplace.transferServiceOwnership(sids[0], accounts[1], { from: accounts[1] }), errors.ERR_SERVICE_NOT_OWNER)
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
    await marketplace.createService(sids[0], { from: accounts[0] })
  })

  describe('service versions', async () => {
    it('should not have any version', async () => {
      assert.equal(await marketplace.serviceVersionsLength(sids[0]), 0)
    })
    it('should fail not service owner', async () => {
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].manifest, versions[0].manifestProtocol, { from: accounts[1] }), errors.ERR_SERVICE_NOT_OWNER)
    })
    it('should fail hash is too long', async () => {
      await truffleAssert.fails(marketplace.createServiceVersion(sids[0], ZERO_HASH + '1', versions[0].manifest, versions[0].manifestProtocol, { from: accounts[0] }))
    })
    it('should fail get version list count - service not exist', async () => {
      await truffleAssert.reverts(marketplace.serviceVersionsLength(sids[1]), errors.ERR_SERVICE_NOT_EXIST)
    })
    it('should fail get version list item - service not exist', async () => {
      await truffleAssert.reverts(marketplace.serviceVersionHash(sids[1], 0), errors.ERR_SERVICE_NOT_EXIST)
    })
    it('should fail get version - service not exist', async () => {
      await truffleAssert.reverts(marketplace.serviceVersion(sids[1], versions[0].hash), errors.ERR_SERVICE_NOT_EXIST)
    })
    it('should fail manifest empty', async () => {
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, '0x00', versions[0].manifestProtocol, { from: accounts[0] }), errors.ERR_VERSION_MANIFEST_LEN)
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, '0x0000', versions[0].manifestProtocol, { from: accounts[0] }), errors.ERR_VERSION_MANIFEST_LEN)
    })
    it('should fail manifest protocol empty', async () => {
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].manifest, '0x00', { from: accounts[0] }), errors.ERR_VERSION_MANIFEST_PROTOCOL_LEN)
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].manifest, '0x00', { from: accounts[0] }), errors.ERR_VERSION_MANIFEST_PROTOCOL_LEN)
    })
    it('version should not exist', async () => {
      assert.isFalse(await marketplace.isServiceVersionExist(sids[0], versions[0].hash))
    })
    it('should create service version', async () => {
      await marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].manifest, versions[0].manifestProtocol, { from: accounts[0] })
    })
    it('should fail create service with existing version', async () => {
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].manifest, versions[0].manifestProtocol, { from: accounts[0] }), errors.ERR_VERSION_EXIST)
    })
    it('should have one service version', async () => {
      assert.equal(await marketplace.serviceVersionsLength(sids[0]), 1)
      assert.isTrue(await marketplace.isServiceVersionExist(sids[0], versions[0].hash))
      const version = await marketplace.serviceVersion(sids[0], versions[0].hash)
      assert.equal(version.manifest, versions[0].manifest)
      assert.equal(version.manifestProtocol, versions[0].manifestProtocol)
      assert.equal(await marketplace.serviceVersionHash(sids[0], 0), versions[0].hash)
    })
    it('should create 2nd service version', async () => {
      await marketplace.createServiceVersion(sids[0], versions[1].hash, versions[1].manifest, versions[1].manifestProtocol, { from: accounts[0] })
    })
    it('should have two service versions', async () => {
      assert.equal(await marketplace.serviceVersionsLength(sids[0]), 2)
      assert.isTrue(await marketplace.isServiceVersionExist(sids[0], versions[1].hash))
      const version = await marketplace.serviceVersion(sids[0], versions[1].hash)
      assert.equal(version.manifest, versions[1].manifest)
      assert.equal(version.manifestProtocol, versions[1].manifestProtocol)
      assert.equal(await marketplace.serviceVersionHash(sids[0], 1), versions[1].hash)
    })
    it('should set create time', async () => {
      const tx = await marketplace.createServiceVersion(sids[0], versions[2].hash, versions[2].manifest, versions[2].manifestProtocol, { from: accounts[0] })
      const block = await web3.eth.getBlock(tx.receipt.blockHash)
      const version = await marketplace.serviceVersion(sids[0], versions[2].hash)
      assert.equal(version.createTime, block.timestamp)
    })
  })
})

contract('Marketplace', async ([ owner, ...accounts ]) => {
  before(async () => {
    token = await Token.new('MESG', 'MESG', 18, 25 * 10e6, { from: owner })
    marketplace = await Marketplace.new(token.address, { from: owner })
    await marketplace.createService(sids[0], { from: accounts[0] })
  })

  describe('service offers', async () => {
    it('should not have any offer', async () => {
      assert.equal(await marketplace.serviceOffersLength(sids[0]), 0)
    })
    it('should fail not service owner', async () => {
      await truffleAssert.reverts(marketplace.createServiceOffer(sids[0], offers[0].price, offers[0].duration, { from: accounts[1] }), errors.ERR_SERVICE_NOT_OWNER)
    })
    it('should fail get offers count - service not exist', async () => {
      await truffleAssert.reverts(marketplace.serviceOffersLength(sids[1]), errors.ERR_SERVICE_NOT_EXIST)
    })
    it('should fail get offer - service not exist', async () => {
      await truffleAssert.reverts(marketplace.serviceOffer(sids[1], 0), errors.ERR_SERVICE_NOT_EXIST)
    })
    it('should fail create service offer without version', async () => {
      await truffleAssert.reverts(marketplace.createServiceOffer(sids[0], offers[0].price, offers[0].duration, { from: accounts[0] }), errors.ERR_OFFER_NO_VERSION)
    })
    it('should create service version', async () => {
      await marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].manifest, versions[0].manifestProtocol, { from: accounts[0] })
    })
    it('should fail duration is 0', async () => {
      await truffleAssert.reverts(marketplace.createServiceOffer(sids[0], offers[0].price, 0, { from: accounts[0] }), errors.ERR_OFFER_DURATION_MIN)
    })
    it('offer should not exist', async () => {
      assert.isFalse(await marketplace.isServiceOfferExist(sids[0], 0))
    })
    it('should create service offer', async () => {
      await marketplace.createServiceOffer(sids[0], offers[0].price, offers[0].duration, { from: accounts[0] })
    })
    it('should have one service offer', async () => {
      assert.equal(await marketplace.serviceOffersLength(sids[0]), 1)
      assert.isTrue(await marketplace.isServiceOfferExist(sids[0], 0))
      const offer = await marketplace.serviceOffer(sids[0], 0)
      assert.equal(offer.price, offers[0].price)
      assert.equal(offer.duration, offers[0].duration)
      assert.isTrue(offer.active)
    })
    it('should create 2nd service version', async () => {
      await marketplace.createServiceOffer(sids[0], offers[1].price, offers[1].duration, { from: accounts[0] })
    })
    it('should have two service offers', async () => {
      assert.equal(await marketplace.serviceOffersLength(sids[0]), 2)
      assert.isTrue(await marketplace.isServiceOfferExist(sids[0], 1))
      const offer = await marketplace.serviceOffer(sids[0], 1)
      assert.equal(offer.price, offers[1].price)
      assert.equal(offer.duration, offers[1].duration)
      assert.isTrue(offer.active)
    })
    it('should fail - disable service offer only owner', async () => {
      await truffleAssert.reverts(marketplace.disableServiceOffer(sids[0], 0, { from: accounts[1] }), errors.ERR_SERVICE_NOT_OWNER)
    })
    it('should fail - disable service offer not exist', async () => {
      await truffleAssert.reverts(marketplace.disableServiceOffer(sids[0], offers.length + 1, { from: accounts[0] }), errors.ERR_OFFER_NOT_EXIST)
    })
    it('should disable service offer', async () => {
      await marketplace.disableServiceOffer(sids[0], 0, { from: accounts[0] })
    })
    it('should service offer be disabled', async () => {
      const offer = await marketplace.serviceOffer(sids[0], 0)
      assert.isFalse(offer.active)
    })
    it('should create service offer with duration set to infinity', async () => {
      await marketplace.createServiceOffer(sids[0], offers[2].price, offers[2].duration, { from: accounts[0] })
    })
    it('should set create time', async () => {
      const tx = await marketplace.createServiceOffer(sids[0], offers[3].price, offers[3].duration, { from: accounts[0] })
      const block = await web3.eth.getBlock(tx.receipt.blockHash)
      const offer = await marketplace.serviceOffer(sids[0], 3)
      assert.equal(offer.createTime, block.timestamp)
    })
  })
})

contract('Marketplace', async ([ owner, ...accounts ]) => {
  before(async () => {
    token = await Token.new('MESG', 'MESG', 18, 25 * 10e6, { from: owner })
    marketplace = await Marketplace.new(token.address, { from: owner })
    await marketplace.createService(sids[0], { from: accounts[0] })
    await marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].manifest, versions[0].manifestProtocol, { from: accounts[0] })
    for (let i = 0; i < offers.length; i++) {
      await marketplace.createServiceOffer(sids[0], offers[i].price, offers[i].duration, { from: accounts[0] })
    }
  })

  describe('service purchase', async () => {
    it('should not have any purchases', async () => {
      assert.equal(await marketplace.servicePurchasesLength(sids[0]), 0)
    })
    it('should fail get purchases list count - service not exist', async () => {
      await truffleAssert.reverts(marketplace.servicePurchasesLength(sids[1]), errors.ERR_SERVICE_NOT_EXIST)
    })
    it('should fail get purchases list item - service not exist', async () => {
      await truffleAssert.reverts(marketplace.servicePurchaseAddress(sids[1], 0), errors.ERR_SERVICE_NOT_EXIST)
    })
    it('should fail get purchases - service not exist', async () => {
      await truffleAssert.reverts(marketplace.servicePurchase(sids[1], accounts[0]), errors.ERR_SERVICE_NOT_EXIST)
    })
    it('should get purchases expire = 0', async () => {
      const purchase = await marketplace.servicePurchase(sids[0], accounts[0])
      assert.equal(purchase.expire, 0)
    })
    it('should has purchased return true for service owner', async () => {
      assert.isTrue(await marketplace.isAuthorized(sids[0], accounts[0]))
    })
    it('should has purchased return false', async () => {
      assert.isFalse(await marketplace.isAuthorized(sids[0], accounts[1]))
    })
    it('should fail purchase - service owner can\'t buy', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[0], 0, { from: accounts[0] }), errors.ERR_PURCHASE_OWNER)
    })
    it('should fail purchase - service not exist', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[1], 0, { from: accounts[1] }), errors.ERR_SERVICE_NOT_EXIST)
    })
    it('should fail purchase - service offer not exist', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[0], offers.length + 1, { from: accounts[1] }), errors.ERR_OFFER_NOT_EXIST)
    })
    it('should fail purchase - balance < offer.price', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[0], 0, { from: accounts[1] }), errors.ERR_PURCHASE_TOKEN_BALANCE)
    })
    it('should transfer tokens', async () => {
      await token.transfer(accounts[1], initTokenBalance, { from: owner })
      await token.transfer(accounts[2], initTokenBalance, { from: owner })
      await token.transfer(accounts[3], initTokenBalance, { from: owner })
    })
    it('should fail purchase - sender not approve', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[0], 0, { from: accounts[1] }), errors.ERR_PURCHASE_TOKEN_APPROVE)
    })
    it('offer should not exist', async () => {
      assert.isFalse(await marketplace.isServicesPurchaseExist(sids[0], accounts[1]))
    })
    it('should purchase service offer', async () => {
      await token.approve(marketplace.address, offers[0].price, { from: accounts[1] })
      const tx = await marketplace.purchase(sids[0], 0, { from: accounts[1] })
      const block = await web3.eth.getBlock(tx.receipt.blockHash)

      assert.equal(await marketplace.servicePurchasesLength(sids[0]), 1)
      assert.equal(await marketplace.servicePurchaseAddress(sids[0], 0), accounts[1])
      assert.isTrue(await marketplace.isAuthorized(sids[0], accounts[1]))

      const purchase = await marketplace.servicePurchase(sids[0], accounts[1])
      assert.equal(purchase.expire, block.timestamp + offers[0].duration)

      assert.isTrue(await marketplace.isServicesPurchaseExist(sids[0], accounts[1]))
    })
    it('should purchased service expire', async () => {
      await sleep(offers[0].duration + 1)
      assert.isFalse(await marketplace.isAuthorized(sids[0], accounts[1]))
    })
    it('should transfer token to service owner after purchase', async () => {
      assert.equal(await token.balanceOf(accounts[0]), offers[0].price)
      assert.equal(await token.balanceOf(accounts[1]), initTokenBalance - offers[0].price)
    })
    it('should purchase service offer with 2nd account', async () => {
      await token.approve(marketplace.address, offers[0].price, { from: accounts[2] })
      await marketplace.purchase(sids[0], 0, { from: accounts[2] })
      assert.equal(await marketplace.servicePurchasesLength(sids[0]), 2)
      assert.isTrue(await marketplace.isAuthorized(sids[0], accounts[2]))
    })
    it('should disable service offer', async () => {
      await marketplace.disableServiceOffer(sids[0], 0, { from: accounts[0] })
    })
    it('should fail purchase - service offer not active', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[0], 0), errors.ERR_OFFER_NOT_ACTIVE)
    })
    it('should purchase service offer twice', async () => {
      await token.approve(marketplace.address, 2 * offers[1].price, { from: accounts[1] })
      const tx = await marketplace.purchase(sids[0], 1, { from: accounts[1] })
      await marketplace.purchase(sids[0], 1, { from: accounts[1] })
      const block = await web3.eth.getBlock(tx.receipt.blockHash)

      assert.equal(await marketplace.servicePurchasesLength(sids[0]), 2)
      assert.equal(await marketplace.servicePurchaseAddress(sids[0], 0), accounts[1])

      const purchase = await marketplace.servicePurchase(sids[0], accounts[1])
      assert.equal(purchase.expire, block.timestamp + 2 * offers[1].duration)
    })
    it('should purchase service with infinity offer', async () => {
      await token.approve(marketplace.address, offers[2].price, { from: accounts[1] })
      await marketplace.purchase(sids[0], 2, { from: accounts[1] })
      const purchase = await marketplace.servicePurchase(sids[0], accounts[1])
      assert.equal(purchase.expire.cmp(INFINITY), 0)
    })
    it('should fail purchase service with infinity expire', async () => {
      await token.approve(marketplace.address, offers[2].price, { from: accounts[1] })
      await truffleAssert.reverts(marketplace.purchase(sids[0], 2, { from: accounts[1] }), errors.ERR_PURCHASE_INFINITY)
    })
    it('should transfer service', async () => {
      await marketplace.transferServiceOwnership(sids[0], accounts[1], { from: accounts[0] })
    })
    it('should has purchased return true for new service owner', async () => {
      assert.isTrue(await marketplace.isAuthorized(sids[0], accounts[1]))
    })
    it('should has purchased return false for previous service owner', async () => {
      assert.isFalse(await marketplace.isAuthorized(sids[0], accounts[0]))
    })
    it('should set create time', async () => {
      await token.approve(marketplace.address, offers[3].price, { from: accounts[3] })
      const tx = await marketplace.purchase(sids[0], 3, { from: accounts[3] })
      const block = await web3.eth.getBlock(tx.receipt.blockHash)
      const purchase = await marketplace.servicePurchase(sids[0], accounts[3])
      assert.equal(purchase.createTime, block.timestamp)
    })
  })
})
