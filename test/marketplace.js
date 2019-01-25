/* eslint-env mocha */
/* global contract, artifacts */

const assert = require('chai').assert
const truffleAssert = require('truffle-assertions')
const { newDefaultToken, BN, hexToAscii, asciiToHex } = require('./utils')

const Marketplace = artifacts.require('Marketplace')
const Token = artifacts.require('MESGToken')

// Errors from contract
const errorServiceOwner = 'Service owner is not the same as the sender'
const errorServiceSidAlreadyUsed = 'Service\'s sid is already used'
const errorServiceNotFound = 'Service not found'
const errorServiceVersionNotFound = 'Version not found'
const errorServicePaymentNotFound = 'Payment not found'
const errorServiceVersionHashAlreadyExist = 'Version\'s hash already exists'
const errorServicePaymentAlreadyPaid = 'Sender already paid for this service'
const errorServicePaymentNotEnoughBalance = 'Sender doesn\'t have enough balance to pay this service'
const errorServicePaymentDidNotAllow = 'Sender didn\'t approve this contract to spend on his behalf. Execute approve function on the token contract'
const errorTransferOwnershipAddress0 = 'New Owner cannot be address 0'
const errorTransferOwnershipSameAddress = 'New Owner is already current owner'

// Assert functions

// Service
const assertEventServiceCreated = (tx, serviceIndex, sid, price, owner) => {
  truffleAssert.eventEmitted(tx, 'ServiceCreated')
  const event = tx.logs[0].args
  assert.isTrue(event.serviceIndex.eq(BN(serviceIndex)))
  assert.equal(hexToAscii(event.sid), sid)
  assert.equal(event.owner, owner)
  assert.equal(event.price, price)
}
const assertService = (service, sid, price, owner) => {
  assert.equal(service.owner, owner)
  assert.equal(hexToAscii(service.sid), sid)
  assert.equal(service.price, price)
}
const assertEventServicePriceChanged = (tx, serviceIndex, sid, previousPrice, newPrice) => {
  truffleAssert.eventEmitted(tx, 'ServicePriceChanged')
  const event = tx.logs[0].args
  assert.isTrue(event.serviceIndex.eq(BN(serviceIndex)))
  assert.equal(hexToAscii(event.sid), sid)
  assert.equal(event.previousPrice, previousPrice)
  assert.equal(event.newPrice, newPrice)
}
const assertEventServiceOwnershipTransferred = (tx, serviceIndex, sid, previousOwner, newOwner) => {
  truffleAssert.eventEmitted(tx, 'ServiceOwnershipTransferred')
  const event = tx.logs[0].args
  assert.isTrue(event.serviceIndex.eq(BN(serviceIndex)))
  assert.equal(hexToAscii(event.sid), sid)
  assert.equal(event.previousOwner, previousOwner)
  assert.equal(event.newOwner, newOwner)
}

// Service version
const assertEventServiceVersionCreated = (tx, serviceIndex, sid, versionHash, versionMetadata) => {
  truffleAssert.eventEmitted(tx, 'ServiceVersionCreated')
  const event = tx.logs[0].args
  assert.isTrue(event.serviceIndex.eq(BN(serviceIndex)))
  assert.equal(hexToAscii(event.sid), sid)
  assert.equal(event.hash, versionHash)
  assert.equal(hexToAscii(event.metadata), versionMetadata)
}
const assertServiceVersion = (version, versionHash, versionMetadata) => {
  assert.equal(version.hash, versionHash)
  assert.equal(hexToAscii(version.metadata), versionMetadata)
}

// Service payment
const assertEventServicePaid = (tx, serviceIndex, sid, price, purchaser, seller) => {
  truffleAssert.eventEmitted(tx, 'ServicePaid')
  const event = tx.logs[0].args
  assert.isTrue(event.serviceIndex.eq(BN(serviceIndex)))
  assert.equal(hexToAscii(event.sid), sid)
  assert.equal(event.purchaser, purchaser)
  assert.equal(event.seller, seller)
  assert.equal(event.price, price)
}
const assertServicePayment = (payment, purchaser) => {
  assert.equal(payment, purchaser)
}

const sid = 'test-service-0'
const sid2 = 'test-service-1'
const sidNotExist = 'test-service-not-exist'
const price = 1000
const price2 = 2000
const version = {
  hash: '0xa666c79d6eccdcdd670d25997b5ec7d3f7f8fc94',
  metadata: 'https://download.com/core.tar'
}
const version2 = {
  hash: '0xb444c79d6eccdcdd670d25997b5ec7d3f7f8fc94',
  metadata: 'https://get.com/core.tar'
}
const versionNotExisting = {
  hash: '0xc5555c79d6eccdcdd670d25997b5ec7d3f7f8fc94',
  metadata: 'https://notFound.com/core.tar'
}

const purchaserInitialBalance = 1000000

module.exports = { sid, version, price }

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
        const tx = await marketplace.createService(asciiToHex(sid), price, { from: developer })
        assertEventServiceCreated(tx, 0, sid, price, developer)
      })

      it('should have one service', async () => {
        assert.equal(await marketplace.getServicesCount(), 1)
        const serviceIndex = await marketplace.getServiceIndex(asciiToHex(sid))
        assert.equal(serviceIndex, 0)
        const service = await marketplace.services(serviceIndex)
        assertService(service, sid, price, developer)
      })

      it('should not be able to create a service with existing sid', async () => {
        await truffleAssert.reverts(marketplace.createService(asciiToHex(sid), price, { from: developer2 }), errorServiceSidAlreadyUsed)
      })

      it('should fail when getting service with not existing sid', async () => {
        await truffleAssert.reverts(marketplace.getServiceIndex(asciiToHex(sidNotExist)), errorServiceNotFound)
      })

      it('should create a second service', async () => {
        const tx = await marketplace.createService(asciiToHex(sid2), price, { from: developer })
        assertEventServiceCreated(tx, 1, sid2, price, developer)
      })

      it('should have two service', async () => {
        assert.equal(await marketplace.getServicesCount(), 2)
        const serviceIndex = await marketplace.getServiceIndex(asciiToHex(sid2))
        assert.equal(serviceIndex, 1)
        const service = await marketplace.services(serviceIndex)
        assertService(service, sid2, price, developer)
      })
    })

    describe('service price', async () => {
      it('should change service price', async () => {
        const tx = await marketplace.changeServicePrice(0, price2, { from: developer })
        assertEventServicePriceChanged(tx, 0, sid, price, price2)
      })

      it('should have changed service price', async () => {
        assert.equal(await marketplace.getServicesCount(), 2)
        const service = await marketplace.services(0)
        assertService(service, sid, price2, developer)
      })
    })

    describe('service version', async () => {
      it('should create a version', async () => {
        const tx = await marketplace.createServiceVersion(0, version.hash, asciiToHex(version.metadata), { from: developer })
        assertEventServiceVersionCreated(tx, 0, sid, version.hash, version.metadata)
      })

      it('should have one version', async () => {
        assert.equal(await marketplace.getServiceVersionsCount(0), 1)
        const _version = await marketplace.getServiceVersion(0, 0)
        assertServiceVersion(_version, version.hash, version.metadata)
      })

      it('should create an other version', async () => {
        const tx = await marketplace.createServiceVersion(0, version2.hash, asciiToHex(version2.metadata), { from: developer })
        assertEventServiceVersionCreated(tx, 0, sid, version2.hash, version2.metadata)
      })

      it('should have two version', async () => {
        assert.equal(await marketplace.getServiceVersionsCount(0), 2)
        // check version
        const _version = await marketplace.getServiceVersion(0, 0)
        assertServiceVersion(_version, version.hash, version.metadata)
        // check version2
        const _version2 = await marketplace.getServiceVersion(0, 1)
        assertServiceVersion(_version2, version2.hash, version2.metadata)
      })

      it('should not be able to create a version with same hash', async () => {
        await truffleAssert.reverts(marketplace.createServiceVersion(0, version2.hash, asciiToHex(version2.metadata), { from: developer }), errorServiceVersionHashAlreadyExist)
      })

      it('should fail when getting service version with not existing hash', async () => {
        await truffleAssert.reverts(marketplace.getServiceVersionIndex(0, versionNotExisting.hash), errorServiceVersionNotFound)
      })
    })

    describe('service payment', async () => {
      it('should have not paid service', async () => {
        assert.equal(await marketplace.hasPaid(0, { from: purchaser }), false)
      })

      it('should pay a service', async () => {
        await token.approve(marketplace.address, price2, { from: purchaser })
        const tx = await marketplace.pay(0, { from: purchaser })
        assertEventServicePaid(tx, 0, sid, price2, purchaser, developer)
      })

      it('should have paid service', async () => {
        assert.equal(await marketplace.hasPaid(0, { from: purchaser }), true)
        assert.equal(await marketplace.getServicePaymentsCount(0), 1)
        const _payment = await marketplace.getServicePayment(0, 0)
        assertServicePayment(_payment, purchaser)
      })

      it('tokens should have been transferred from purchaser to developer', async () => {
        const servicePrice = (await marketplace.services(0)).price
        const purchaserBalance = await token.balanceOf(purchaser)
        const developerBalance = await token.balanceOf(developer)

        assert.isTrue(purchaserBalance.eq(BN(purchaserInitialBalance).sub(servicePrice)))
        assert.isTrue(developerBalance.eq(servicePrice))
      })

      it('should fail when marketplace is not allowed to spend on behalf of purchaser', async () => {
        truffleAssert.fails(marketplace.pay(0, { from: purchaser2 }), errorServicePaymentDidNotAllow)
      })

      it('should not be able to pay twice the same service', async () => {
        await truffleAssert.reverts(marketplace.pay(0, { from: purchaser }), errorServicePaymentAlreadyPaid)
      })

      it('should not be able to pay without enough balance', async () => {
        await truffleAssert.reverts(marketplace.pay(0, { from: other }), errorServicePaymentNotEnoughBalance)
      })

      it('should fail when getting service payment with not existing purchaser', async () => {
        await truffleAssert.reverts(marketplace.getServicePaymentIndex(0, other), errorServicePaymentNotFound)
      })
    })

    describe('service ownership', async () => {
      it('original owner should have the service ownership', async () => {
        assert.equal(await marketplace.getServicesCount(), 2)
        assert.isTrue(await marketplace.isServiceOwner(0, { from: developer }))
      })

      it('other should not have the service ownership', async () => {
        assert.equal(await marketplace.getServicesCount(), 2)
        assert.isFalse(await marketplace.isServiceOwner(0, { from: other }))
      })

      it('should transfer service ownership', async () => {
        const tx = await marketplace.transferServiceOwnership(0, developer2,
          { from: developer }
        )
        assertEventServiceOwnershipTransferred(tx, 0, sid, developer, developer2)
      })

      it('new service owner should have the service ownership', async () => {
        assert.equal(await marketplace.getServicesCount(), 2)
        assert.isTrue(await marketplace.isServiceOwner(0, { from: developer2 }))
      })

      it('original owner should not have the service ownership', async () => {
        assert.equal(await marketplace.getServicesCount(), 2)
        assert.isFalse(await marketplace.isServiceOwner(0, { from: developer }))
      })

      it('should fail when new owner owner is address 0', async () => {
        await truffleAssert.reverts(marketplace.transferServiceOwnership(0, '0x0000000000000000000000000000000000000000', { from: developer2 }), errorTransferOwnershipAddress0)
      })

      it('should fail when new owner owner is the same as current owner', async () => {
        await truffleAssert.reverts(marketplace.transferServiceOwnership(0, developer2, { from: developer2 }), errorTransferOwnershipSameAddress)
      })

      describe('test modifier onlyServiceOwner', async () => {
        it('original owner should not be able to transfer service ownership', async () => {
          await truffleAssert.reverts(marketplace.transferServiceOwnership(0, other, { from: developer }), errorServiceOwner)
        })
        it('original owner should not be able to change service price', async () => {
          await truffleAssert.reverts(marketplace.changeServicePrice(0, price, { from: developer }), errorServiceOwner)
        })
        it('original owner should not be able to create a service version', async () => {
          await truffleAssert.reverts(marketplace.createServiceVersion(0, version.hash, asciiToHex(version.metadata), { from: developer }), errorServiceOwner)
        })
      })
    })
  })
})
