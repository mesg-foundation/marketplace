/* eslint-env mocha */
/* global contract, artifacts */
const assert = require('chai').assert
const { asciiToHex, padRight } = require('web3-utils')
const truffleAssert = require('truffle-assertions')

const Marketplace = artifacts.require('Marketplace')
const Token = artifacts.require('MESGToken')

// useful shortcut and constant
const padRight64 = x => padRight(x, 64)
const sleep = sec => new Promise(resolve => setTimeout(resolve, sec * 1000))

// contracts object
let token = null
let marketplace = null

// constants used for creating services, versions and offers
const sids = [
  asciiToHex('test-service-0'),
  asciiToHex('test-service-1')
]

const versions = [
  {
    hash: '0x0000000000000000000000000000000000000001',
    metadata: asciiToHex('https://mesg.com/download/v1/core.tar')
  },
  {
    hash: '0x0000000000000000000000000000000000000002',
    metadata: asciiToHex('https://mesg.com/download/v2/core.tar')
  }
]

const offers = [
  {
    price: 1,
    duration: 1
  },
  {
    price: 2,
    duration: 2
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
      assert.equal(await marketplace.getServicesListCount(), 0)
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
      assert.equal(event.sid, padRight64(sids[0]))
      assert.equal(event.owner, accounts[0])
    })
    it('ServiceVersionCreated', async () => {
      const tx = await marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].metadata, { from: accounts[0] })
      truffleAssert.eventEmitted(tx, 'ServiceVersionCreated')
      const event = tx.logs[0].args
      assert.equal(event.sid, padRight64(sids[0]))
      assert.equal(event.hash, padRight64(versions[0].hash))
      assert.equal(event.metadata, versions[0].metadata)
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
      const now = Date.now() / 1000
      const tx = await marketplace.purchase(sids[0], 0, { from: accounts[1] })
      truffleAssert.eventEmitted(tx, 'ServicePurchased')
      const event = tx.logs[0].args
      assert.equal(event.sid, padRight64(sids[0]))
      assert.equal(event.offerIndex, 0)
      assert.equal(event.purchaser, accounts[1])
      assert.equal(event.price, offers[0].price)
      assert.equal(event.duration, offers[0].duration)
      const expire = event.expire.toNumber()
      assert.isTrue(now <= expire && expire <= now + offers[0].duration)
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
      await truffleAssert.reverts(marketplace.createService(sids[0], { from: accounts[0] }))
    })
    it('transferServiceOwnership', async () => {
      await truffleAssert.reverts(marketplace.transferServiceOwnership(sids[0], accounts[1], { from: accounts[0] }))
    })
    it('createServiceVersion', async () => {
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].metadata, { from: accounts[0] }))
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
      await marketplace.createService(sids[0], { from: accounts[0] })
    })
    it('should have one service', async () => {
      assert.equal(await marketplace.getServicesListCount(), 1)
      assert.equal(await marketplace.services(sids[0]), accounts[0])
    })
    it('should fail when create with existing sids[0]', async () => {
      await truffleAssert.reverts(marketplace.createService(sids[0], { from: accounts[0] }))
    })
    it('should create 2nd service', async () => {
      await marketplace.createService(sids[1], { from: accounts[0] })
    })
    it('should have two services', async () => {
      assert.equal(await marketplace.getServicesListCount(), 2)
      assert.equal(await marketplace.services(sids[1]), accounts[0])
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
      await truffleAssert.reverts(marketplace.transferServiceOwnership(asciiToHex('-'), accounts[0], { from: accounts[0] }))
    })
    it('should fail when new owner address equals 0x0', async () => {
      await truffleAssert.reverts(marketplace.transferServiceOwnership(sids[0], '0x0000000000000000000000000000000000000000', { from: accounts[0] }))
    })
    it('should fail when called by not owner', async () => {
      await truffleAssert.reverts(marketplace.transferServiceOwnership(sids[0], accounts[1], { from: accounts[1] }))
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
      assert.equal(await marketplace.getServicesVersionsListCount(sids[0]), 0)
    })
    it('should fail not service owner', async () => {
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].metadata, { from: accounts[1] }))
    })
    it('should fail get version list count - service not exist', async () => {
      await truffleAssert.reverts(marketplace.getServicesVersionsListCount(sids[1]))
    })
    it('should fail get version - service not exist', async () => {
      await truffleAssert.reverts(marketplace.getServicesVersion(sids[1], versions[0].hash))
    })
    it('should fail metadata empty', async () => {
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, '0x00', { from: accounts[0] }))
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, '0x0000', { from: accounts[0] }))
    })
    it('should create service version', async () => {
      await marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].metadata, { from: accounts[0] })
    })
    it('should fail create service with existing version', async () => {
      await truffleAssert.reverts(marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].metadata, { from: accounts[0] }))
    })
    it('should have one service version', async () => {
      assert.equal(await marketplace.getServicesVersionsListCount(sids[0]), 1)
      assert.equal(await marketplace.getServicesVersion(sids[0], versions[0].hash), versions[0].metadata)
    })
    it('should create 2nd service version', async () => {
      await marketplace.createServiceVersion(sids[0], versions[1].hash, versions[1].metadata, { from: accounts[0] })
    })
    it('should have two service versions', async () => {
      assert.equal(await marketplace.getServicesVersionsListCount(sids[0]), 2)
      assert.equal(await marketplace.getServicesVersion(sids[0], versions[1].hash), versions[1].metadata)
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
      assert.equal(await marketplace.getServicesOffersCount(sids[0]), 0)
    })
    it('should fail not service owner', async () => {
      await truffleAssert.reverts(marketplace.createServiceOffer(sids[0], offers[0].price, offers[0].duration, { from: accounts[1] }))
    })
    it('should fail get offers count - service not exist', async () => {
      await truffleAssert.reverts(marketplace.getServicesOffersCount(sids[1]))
    })
    it('should fail get offer - service not exist', async () => {
      await truffleAssert.reverts(marketplace.getServicesOffer(sids[1], 0))
    })
    it('should fail create service offer without version', async () => {
      await truffleAssert.reverts(marketplace.createServiceOffer(sids[0], offers[0].price, offers[0].duration, { from: accounts[0] }))
    })
    it('should create service version', async () => {
      await marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].metadata, { from: accounts[0] })
    })
    it('should fail price is 0', async () => {
      await truffleAssert.reverts(marketplace.createServiceOffer(sids[0], 0, offers[0].duration, { from: accounts[0] }))
    })
    it('should fail duration is 0', async () => {
      await truffleAssert.reverts(marketplace.createServiceOffer(sids[0], offers[0].price, 0, { from: accounts[0] }))
    })
    it('should create service offer', async () => {
      await marketplace.createServiceOffer(sids[0], offers[0].price, offers[0].duration, { from: accounts[0] })
    })
    it('should have one service offer', async () => {
      assert.equal(await marketplace.getServicesOffersCount(sids[0]), 1)
      const offer = await marketplace.getServicesOffer(sids[0], 0)
      assert.equal(offer.price, offers[0].price)
      assert.equal(offer.duration, offers[0].duration)
      assert.isTrue(offer.active)
    })
    it('should create 2nd service version', async () => {
      await marketplace.createServiceOffer(sids[0], offers[1].price, offers[1].duration, { from: accounts[0] })
    })
    it('should have two service offers', async () => {
      assert.equal(await marketplace.getServicesOffersCount(sids[0]), 2)
      const offer = await marketplace.getServicesOffer(sids[0], 1)
      assert.equal(offer.price, offers[1].price)
      assert.equal(offer.duration, offers[1].duration)
      assert.isTrue(offer.active)
    })
    it('should fail - disable service offer only owner', async () => {
      await truffleAssert.reverts(marketplace.disableServiceOffer(sids[0], 0, { from: accounts[1] }))
    })
    it('should fail - disable service offer not exist', async () => {
      await truffleAssert.reverts(marketplace.disableServiceOffer(sids[0], 2, { from: accounts[0] }))
    })
    it('should disable service offer', async () => {
      await marketplace.disableServiceOffer(sids[0], 0, { from: accounts[0] })
    })
    it('should service offer be disabled', async () => {
      const offer = await marketplace.getServicesOffer(sids[0], 0)
      assert.isFalse(offer.active)
    })
  })
})

contract('Marketplace', async ([ owner, ...accounts ]) => {
  before(async () => {
    token = await Token.new('MESG', 'MESG', 18, 25 * 10e6, { from: owner })
    marketplace = await Marketplace.new(token.address, { from: owner })
    await marketplace.createService(sids[0], { from: accounts[0] })
    await marketplace.createServiceVersion(sids[0], versions[0].hash, versions[0].metadata, { from: accounts[0] })
    await marketplace.createServiceOffer(sids[0], offers[0].price, offers[0].duration, { from: accounts[0] })
    await marketplace.createServiceOffer(sids[0], offers[1].price, offers[1].duration, { from: accounts[0] })
  })

  describe('service purchase', async () => {
    it('should not have any purchases', async () => {
      assert.equal(await marketplace.getServicesPurchasesListCount(sids[0]), 0)
    })
    it('should fail get purchases list count - service not exist', async () => {
      await truffleAssert.reverts(marketplace.getServicesPurchasesListCount(sids[1]))
    })
    it('should fail get purchases - service not exist', async () => {
      await truffleAssert.reverts(marketplace.getServicesPurchases(sids[1], accounts[0]))
    })
    it('should get purchases return 0', async () => {
      assert.equal(await marketplace.getServicesPurchases(sids[0], accounts[0]), 0)
    })
    it('should has purchased return true for service owner', async () => {
      assert.isTrue(await marketplace.isAuthorized(sids[0], { from: accounts[0] }))
    })
    it('should has purchased return false', async () => {
      assert.isFalse(await marketplace.isAuthorized(sids[0], { from: accounts[1] }))
    })
    it('should fail purchase - service not exist', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[1], 0, { from: accounts[0] }))
    })
    it('should fail purchase - service offer not exist', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[0], 1, { from: accounts[0] }))
    })
    it('should fail purchase - service owner can\'t buy', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[0], 0, { from: accounts[0] }))
    })
    it('should fail purchase - balance < offer.price', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[0], 0, { from: accounts[1] }))
    })
    it('should transfer tokens', async () => {
      await token.transfer(accounts[1], initTokenBalance, { from: owner })
      await token.transfer(accounts[2], initTokenBalance, { from: owner })
    })
    it('should fail purchase - sender not approve', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[0], 0, { from: accounts[1] }))
    })
    it('should purchase service offer', async () => {
      await token.approve(marketplace.address, offers[0].price, { from: accounts[1] })
      const now = Date.now() / 1000
      await marketplace.purchase(sids[0], 0, { from: accounts[1] })
      assert.isTrue(await marketplace.isAuthorized(sids[0], { from: accounts[1] }))
      const expire = await marketplace.getServicesPurchases(sids[0], accounts[1])
      assert.isTrue(now <= expire && expire <= now + offers[0].duration)
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
      assert.isTrue(await marketplace.isAuthorized(sids[0], { from: accounts[2] }))
    })
    it('should disable service offer', async () => {
      await marketplace.disableServiceOffer(sids[0], 0, { from: accounts[0] })
    })
    it('should fail purchase - service offer not active', async () => {
      await truffleAssert.reverts(marketplace.purchase(sids[1], accounts[0]))
    })
    it('should purchase service offer twice', async () => {
      await token.approve(marketplace.address, 2 * offers[1].price, { from: accounts[1] })
      await marketplace.purchase(sids[0], 1, { from: accounts[1] })
      await marketplace.purchase(sids[0], 1, { from: accounts[1] })
      const now = Date.now() / 1000
      const expire = await marketplace.getServicesPurchases(sids[0], accounts[1])
      assert.isTrue(now + offers[1].duration <= expire && expire <= now + 2 * offers[1].duration)
    })
    it('should transfer service', async () => {
      await marketplace.transferServiceOwnership(sids[0], accounts[1], { from: accounts[0] })
    })
    it('should has purchased return true for new service owner', async () => {
      assert.isTrue(await marketplace.isAuthorized(sids[0], { from: accounts[1] }))
    })
  })
})
