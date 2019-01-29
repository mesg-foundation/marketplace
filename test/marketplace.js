/* eslint-env mocha */
/* global contract, artifacts */

const assert = require('chai').assert
const truffleAssert = require('truffle-assertions')
const { newDefaultToken, BN, hexToAscii, asciiToHex, sleep } = require('./utils')

const Marketplace = artifacts.require('Marketplace')
const Token = artifacts.require('MESGToken')

// Errors from contract
const errorServiceOwner = 'Service owner is not the same as the sender'
const errorServiceSidAlreadyUsed = 'Service\'s sid is already used'
const errorServiceNotFound = 'Service not found'
const errorServiceVersionNotFound = 'Version not found'
const errorServicePurchaseNotFound = 'Purchase not found'
const errorServiceVersionHashAlreadyExist = 'Version\'s hash already exists'
const errorServicePurchaseAlreadyPurchase = 'Sender already purchased this service'
const errorServicePurchaseNotEnoughBalance = 'Sender doesn\'t have enough balance to pay this service'
const errorServicePurchaseOfferDisabled = 'Cannot purchase a disabled offer'
const errorServicePurchaseDidNotAllow = 'Sender didn\'t approve this contract to spend on his behalf. Execute approve function on the token contract'
const errorTransferOwnershipAddress0 = 'New Owner cannot be address 0'
const errorTransferOwnershipSameAddress = 'New Owner is already current owner'

// Assert functions

// Service
const assertEventServiceCreated = (tx, serviceIndex, sid, owner) => {
  truffleAssert.eventEmitted(tx, 'ServiceCreated')
  const event = tx.logs[0].args
  console.log('event.sid', event.sid)
  assert.equal(hexToAscii(event.sid), sid)
  assert.equal(event.owner, owner)
}
const assertService = (service, sid, owner) => {
  assert.equal(service.owner, owner)
  assert.equal(hexToAscii(service.sid), sid)
}

const assertEventServiceOwnershipTransferred = (tx, serviceIndex, sid, previousOwner, newOwner) => {
  truffleAssert.eventEmitted(tx, 'ServiceOwnershipTransferred')
  const event = tx.logs[0].args
  assert.equal(hexToAscii(event.sid), sid)
  assert.equal(event.previousOwner, previousOwner)
  assert.equal(event.newOwner, newOwner)
}

// Service version
const assertEventServiceVersionCreated = (tx, serviceIndex, sid, versionIndex, versionHash, versionMetadata) => {
  truffleAssert.eventEmitted(tx, 'ServiceVersionCreated')
  const event = tx.logs[0].args
  assert.equal(hexToAscii(event.sid), sid)
  assert.isTrue(event.versionIndex.eq(BN(versionIndex)))
  assert.equal(event.hash, versionHash)
  assert.equal(hexToAscii(event.metadata), versionMetadata)
}
const assertServiceVersion = (version, versionHash, versionMetadata) => {
  assert.equal(version.hash, versionHash)
  assert.equal(hexToAscii(version.metadata), versionMetadata)
}

// Service offer
const assertEventServiceOfferCreated = (tx, serviceIndex, sid, offerIndex, price, duration) => {
  truffleAssert.eventEmitted(tx, 'ServiceOfferCreated')
  const event = tx.logs[0].args
  assert.equal(hexToAscii(event.sid), sid)
  assert.isTrue(event.offerIndex.eq(BN(offerIndex)))
  assert.equal(event.price, price)
  assert.equal(event.duration, duration)
}
const assertEventServiceOfferDisabled = (tx, serviceIndex, sid, offerIndex) => {
  truffleAssert.eventEmitted(tx, 'ServiceOfferDisabled')
  const event = tx.logs[0].args
  assert.equal(hexToAscii(event.sid), sid)
  assert.isTrue(event.offerIndex.eq(BN(offerIndex)))
}
const assertServiceOffer = (offer, price, duration, active) => {
  assert.equal(offer.price, price)
  assert.equal(offer.duration, duration)
  assert.equal(offer.active, active)
}

// Service purchase
const assertEventServicePurchased = (tx, serviceIndex, sid, offerIndex, price, duration, purchaser) => {
  truffleAssert.eventEmitted(tx, 'ServicePurchased')
  const event = tx.logs[0].args
  assert.equal(hexToAscii(event.sid), sid)
  assert.isTrue(event.offerIndex.eq(BN(offerIndex)))
  assert.equal(event.purchaser, purchaser)
  assert.equal(event.price, price)
  assert.equal(event.duration, duration)
}
const assertServicePurchase = (purchase, purchaser, date, offerIndex) => {
  assert.equal(purchase.purchaser, purchaser)
  assert.equal(purchase.offerIndex, offerIndex)
  // compare date with 0, -1 and -2 seconds
  assert.isTrue(purchase.date.eq(BN(date)) || purchase.date.eq(BN(date - 2)) || purchase.date.eq(BN(date - 1)))
}

const sid = 'test-service-0'
const sidHex = asciiToHex(sid)
const sid2 = 'test-service-1'
const sid2Hex = asciiToHex(sid2)
const sidNotExist = 'test-service-not-exist'
const offer = {
  price: 1000,
  duration: 3600
}
const offer2 = {
  price: 2000,
  duration: 1
}
const version = {
  hash: '0xa666c79d6eccdcdd670d25997b5ec7d3f7f8fc94',
  metadata: 'https://download.com/core.tar'
}
const version2 = {
  hash: '0xb444c79d6eccdcdd670d25997b5ec7d3f7f8fc94',
  metadata: 'https://get.com/core.tar'
}
const version3 = {
  hash: '0xb222c79d6eccdcdd670d25997b5ec7d3f7f8fc94',
  metadata: 'https://get.com/core.tar'
}
const versionNotExisting = {
  hash: '0xc555c79d6eccdcdd670d25997b5ec7d3f7f8fc94',
  metadata: 'https://notFound.com/core.tar'
}

const purchaserInitialBalance = 1000000

module.exports = { sid, sidHex, version, offer }

let marketplace = null
let token = null

contract('Marketplace', async ([
  contractOwner,
  developer,
  developer2,
  purchaser,
  purchaser2,
  other
]) => {
  before(async () => {
    token = await newDefaultToken(Token, contractOwner)
    await token.transfer(purchaser, purchaserInitialBalance, { from: contractOwner })
    await token.transfer(purchaser2, purchaserInitialBalance, { from: contractOwner })
  })

  describe('marketplace', async () => {
    before(async () => {
      marketplace = await Marketplace.new(token.address, { from: contractOwner })
      console.log('marketplace address', marketplace.address)
    })

    describe('service creation', async () => {
      it('should create a service', async () => {
        const tx = await marketplace.createService(sidHex, { from: developer })
        assertEventServiceCreated(tx, 0, sid, developer)
      })

      it('should have one service', async () => {
        assert.equal(await marketplace.getServicesCount(), 1)
        const serviceIndex = await marketplace.sidToService(sidHex)
        assert.equal(serviceIndex, 0)
        const service = await marketplace.services(serviceIndex)
        assertService(service, sid, developer)
      })

      it('should not be able to create a service with existing sid', async () => {
        await truffleAssert.reverts(marketplace.createService(sidHex, { from: developer2 }), errorServiceSidAlreadyUsed)
      })

      // it('should fail when getting service with not existing sid', async () => {
      //   await truffleAssert.reverts(marketplace.sidToService(asciiToHex(sidNotExist)), errorServiceNotFound)
      // })

      it('should create a second service', async () => {
        const tx = await marketplace.createService(sid2Hex, { from: developer })
        assertEventServiceCreated(tx, 1, sid2, developer)
      })

      it('should have two service', async () => {
        assert.equal(await marketplace.getServicesCount(), 2)
        const serviceIndex = await marketplace.sidToService(sid2Hex)
        assert.equal(serviceIndex, 1)
        const service = await marketplace.services(serviceIndex)
        assertService(service, sid2, developer)
      })
    })

    describe('service version', async () => {
      it('should create a version', async () => {
        const tx = await marketplace.createServiceVersion(sidHex, version.hash, asciiToHex(version.metadata), { from: developer })
        assertEventServiceVersionCreated(tx, 0, sid, 0, version.hash, version.metadata)
      })

      it('should have one version', async () => {
        assert.equal(await marketplace.getServiceVersionsCount(sidHex), 1)
        const versionIndex = await marketplace.hashToVersion(version.hash)
        assert.equal(versionIndex.serviceIndex, 0)
        assert.equal(versionIndex.versionIndex, 0)
        const _version = await marketplace.getServiceVersion(sidHex, versionIndex.versionIndex)
        assertServiceVersion(_version, version.hash, version.metadata)
      })

      it('should create an other version', async () => {
        const tx = await marketplace.createServiceVersion(sidHex, version2.hash, asciiToHex(version2.metadata), { from: developer })
        assertEventServiceVersionCreated(tx, 0, sid, 1, version2.hash, version2.metadata)
      })

      it('should have two version', async () => {
        assert.equal(await marketplace.getServiceVersionsCount(sidHex), 2)
        // check version
        const versionIndex = await marketplace.hashToVersion(version.hash)
        assert.equal(versionIndex.serviceIndex, 0)
        assert.equal(versionIndex.versionIndex, 0)
        const _version = await marketplace.getServiceVersion(sidHex, versionIndex.versionIndex)
        assertServiceVersion(_version, version.hash, version.metadata)
        // check version2
        const versionIndex2 = await marketplace.hashToVersion(version2.hash)
        assert.equal(versionIndex2.serviceIndex, 0)
        assert.equal(versionIndex2.versionIndex, 1)
        const _version2 = await marketplace.getServiceVersion(sidHex, versionIndex2.versionIndex)
        assertServiceVersion(_version2, version2.hash, version2.metadata)
      })

      it('should not be able to create a version with same hash', async () => {
        await truffleAssert.reverts(marketplace.createServiceVersion(sidHex, version2.hash, asciiToHex(version2.metadata), { from: developer }), errorServiceVersionHashAlreadyExist)
      })

      // it('should fail when getting service version with not existing hash', async () => {
      //   await truffleAssert.reverts(marketplace.hashToVersion(versionNotExisting.hash), errorServiceVersionNotFound)
      // })

      it('should create a version on second service', async () => {
        const tx = await marketplace.createServiceVersion(sid2Hex, version3.hash, asciiToHex(version3.metadata), { from: developer })
        assertEventServiceVersionCreated(tx, 1, sid2, 0, version3.hash, version3.metadata)
      })
    })

    describe('service offer', async () => {
      it('should create a offer', async () => {
        const tx = await marketplace.createServiceOffer(sidHex, offer.price, offer.duration, { from: developer })
        assertEventServiceOfferCreated(tx, 0, sid, 0, offer.price, offer.duration)
      })

      it('should have one offer', async () => {
        assert.equal(await marketplace.getServiceOffersCount(sidHex), 1)
        const _offer = await marketplace.getServiceOffer(sidHex, 0)
        assertServiceOffer(_offer, offer.price, offer.duration, true)
      })

      it('should create an other offer', async () => {
        const tx = await marketplace.createServiceOffer(sidHex, offer2.price, offer2.duration, { from: developer })
        assertEventServiceOfferCreated(tx, 0, sid, 1, offer2.price, offer2.duration)
      })

      it('should have two offer', async () => {
        assert.equal(await marketplace.getServiceOffersCount(sidHex), 2)
        // check offer
        const _offer = await marketplace.getServiceOffer(sidHex, 0)
        assertServiceOffer(_offer, offer.price, offer.duration, true)
        // check offer2
        const _offer2 = await marketplace.getServiceOffer(sidHex, 1)
        assertServiceOffer(_offer2, offer2.price, offer2.duration, true)
      })

      it('should create an offer on second service', async () => {
        const tx = await marketplace.createServiceOffer(sid2Hex, offer.price, offer.duration, { from: developer })
        assertEventServiceOfferCreated(tx, 1, sid2, 0, offer.price, offer.duration)
      })

      it('should disable offer on second service', async () => {
        const tx = await marketplace.disableServiceOffer(sid2Hex, 0, { from: developer })
        assertEventServiceOfferDisabled(tx, 1, sid2, 0)
      })

      it('offer should be disabled', async () => {
        assert.equal(await marketplace.getServiceOffersCount(sid2Hex), 1)
        const _offer = await marketplace.getServiceOffer(sid2Hex, 0)
        assertServiceOffer(_offer, offer.price, offer.duration, false)
      })
    })

    describe('service purchase', async () => {
      it('should have not purchase service', async () => {
        assert.equal(await marketplace.hasPurchased(sidHex, { from: purchaser }), false)
      })

      it('should purchase a service', async () => {
        await token.approve(marketplace.address, offer.price, { from: purchaser })
        const tx = await marketplace.purchase(sidHex, 0, { from: purchaser })
        assertEventServicePurchased(tx, 0, sid, 0, offer.price, offer.duration, purchaser)
      })

      it('should have purchase service', async () => {
        assert.equal(await marketplace.hasPurchased(sidHex, { from: purchaser }), true)
        assert.equal(await marketplace.getServicePurchasesCount(sidHex), 1)
        // const purchaseIndex = await marketplace.getServicePurchaseIndex(sidHex, purchaser)
        // assert.equal(purchaseIndex, 0)
        const purchase = await marketplace.getServicePurchase(sidHex, 0)
        assertServicePurchase(purchase, purchaser, Math.floor(Date.now() / 1000), 0)
      })

      it('tokens should have been transferred from purchaser to developer', async () => {
        const purchaserBalance = await token.balanceOf(purchaser)
        const developerBalance = await token.balanceOf(developer)

        assert.isTrue(purchaserBalance.eq(BN(purchaserInitialBalance).sub(BN(offer.price))))
        assert.isTrue(developerBalance.eq(BN(offer.price)))
      })

      it('should fail when marketplace is not allowed to spend on behalf of purchaser', async () => {
        await truffleAssert.reverts(marketplace.purchase(sidHex, 0, { from: purchaser2 }), errorServicePurchaseDidNotAllow)
      })

      it('should not be able to purchase twice the same service', async () => {
        await truffleAssert.reverts(marketplace.purchase(sidHex, 0, { from: purchaser }), errorServicePurchaseAlreadyPurchase)
      })

      it('should not be able to purchase without enough balance', async () => {
        await truffleAssert.reverts(marketplace.purchase(sidHex, 0, { from: other }), errorServicePurchaseNotEnoughBalance)
      })

      // it('should fail when getting service purchase with not existing purchase', async () => {
      //   await truffleAssert.reverts(marketplace.getServicePurchaseIndex(sidHex, other), errorServicePurchaseNotFound)
      // })

      it('should fail on purchase a service with a disabled offer', async () => {
        await token.approve(marketplace.address, offer2.price, { from: purchaser })
        await truffleAssert.reverts(marketplace.purchase(sid2Hex, 0, { from: purchaser }), errorServicePurchaseOfferDisabled)
      })

      it('purchase should be expired', async () => {
        await token.approve(marketplace.address, offer2.price, { from: purchaser2 })
        const tx = await marketplace.purchase(sidHex, 1, { from: purchaser2 })
        assertEventServicePurchased(tx, 0, sid, 1, offer2.price, offer2.duration, purchaser2)
        assert.equal(await marketplace.hasPurchased(sidHex, { from: purchaser2 }), true)
        await sleep(2 * 1000)
        assert.equal(await marketplace.hasPurchased(sidHex, { from: purchaser2 }), false)
      })
    })

    describe('service ownership', async () => {
      it('original owner should have the service ownership', async () => {
        assert.equal(await marketplace.getServicesCount(), 2)
        assert.isTrue(await marketplace.isServiceOwner(sidHex, { from: developer }))
      })

      it('other should not have the service ownership', async () => {
        assert.equal(await marketplace.getServicesCount(), 2)
        assert.isFalse(await marketplace.isServiceOwner(sidHex, { from: other }))
      })

      it('should transfer service ownership', async () => {
        const tx = await marketplace.transferServiceOwnership(sidHex, developer2,
          { from: developer }
        )
        assertEventServiceOwnershipTransferred(tx, 0, sid, developer, developer2)
      })

      it('new service owner should have the service ownership', async () => {
        assert.equal(await marketplace.getServicesCount(), 2)
        assert.isTrue(await marketplace.isServiceOwner(sidHex, { from: developer2 }))
      })

      it('original owner should not have the service ownership', async () => {
        assert.equal(await marketplace.getServicesCount(), 2)
        assert.isFalse(await marketplace.isServiceOwner(sidHex, { from: developer }))
      })

      it('should fail when new owner owner is address 0', async () => {
        await truffleAssert.reverts(marketplace.transferServiceOwnership(sidHex, '0x0000000000000000000000000000000000000000', { from: developer2 }), errorTransferOwnershipAddress0)
      })

      it('should fail when new owner owner is the same as current owner', async () => {
        await truffleAssert.reverts(marketplace.transferServiceOwnership(sidHex, developer2, { from: developer2 }), errorTransferOwnershipSameAddress)
      })

      describe('test modifier onlyServiceOwner', async () => {
        it('original owner should not be able to transfer service ownership', async () => {
          await truffleAssert.reverts(marketplace.transferServiceOwnership(sidHex, other, { from: developer }), errorServiceOwner)
        })
        it('original owner should not be able to create service offer', async () => {
          await truffleAssert.reverts(marketplace.createServiceOffer(sidHex, offer.price, offer.duration, { from: developer }), errorServiceOwner)
        })
        it('original owner should not be able to disable service offer', async () => {
          await truffleAssert.reverts(marketplace.disableServiceOffer(sidHex, 0, { from: developer }), errorServiceOwner)
        })
        it('original owner should not be able to create a service version', async () => {
          await truffleAssert.reverts(marketplace.createServiceVersion(sidHex, version.hash, asciiToHex(version.metadata), { from: developer }), errorServiceOwner)
        })
      })
    })
  })
})
