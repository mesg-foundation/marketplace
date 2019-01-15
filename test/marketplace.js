/* eslint-env mocha */
/* global contract, artifacts */

const Marketplace = artifacts.require('Marketplace')
const assert = require('chai').assert
const truffleAssert = require('truffle-assertions')
const web3 = require('web3')

const hexToAscii = x => web3.utils.hexToAscii(x).replace(/\u0000/g, '')
const asciiToHex = x => web3.utils.asciiToHex(x)
const BN = x => new web3.utils.BN(x)
// const padRight = x => web3.utils.padRight(x, 64)
// const hexToNumber = x => web3.utils.hexToNumber(x)

// Errors from contract
const errorServiceOwner = 'Service owner is not the same as the sender'
const errorServiceSidAlreadyUsed = 'Service\'s sid is already used'
const errorServiceNotFound = 'Service not found'
const errorServiceVersionNotFound = 'Version not found'
const errorServicePaymentNotFound = 'Payment not found'
const errorServiceVersionHashAlreadyExist = 'Version\'s hash already exists'
const errorServicePaymentAlreadyPaid = 'You already paid for this service'
const errorServicePaymentWrongPrice = 'The service\'s price is different than the value of this transaction'

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
const assertEventServiceVersionCreated = (tx, serviceIndex, versionHash, versionUrl) => {
  truffleAssert.eventEmitted(tx, 'ServiceVersionCreated')
  const event = tx.logs[0].args
  assert.isTrue(event.serviceIndex.eq(BN(serviceIndex)))
  assert.equal(event.hash, versionHash)
  assert.equal(hexToAscii(event.url), versionUrl)
}
const assertServiceVersion = (version, versionHash, versionUrl) => {
  assert.equal(version.hash, versionHash)
  assert.equal(hexToAscii(version.url), versionUrl)
}

// Service payment
const assertEventServicePaid = (tx, serviceIndex, sid, price, purchaser) => {
  truffleAssert.eventEmitted(tx, 'ServicePaid')
  const event = tx.logs[0].args
  assert.isTrue(event.serviceIndex.eq(BN(serviceIndex)))
  assert.equal(hexToAscii(event.sid), sid)
  assert.equal(event.purchaser, purchaser)
  assert.equal(event.price, price)
}
const assertServicePayment = (payment, purchaser) => {
  assert.equal(payment, purchaser)
}

contract('Marketplace', async accounts => {
  const [
    contractOwner,
    contractOwner2,
    developer,
    developer2,
    purchaser,
    purchaser2,
    other
  ] = accounts
  const sid = 'test-service-0'
  const sidNotExist = 'test-service-not-exist'
  const price = 1000000000
  const price2 = 2000000000
  const version = {
    hash: '0xa666c79d6eccdcdd670d25997b5ec7d3f7f8fc94',
    url: 'https://download.com/core.tar'
  }
  const version2 = {
    hash: '0xb444c79d6eccdcdd670d25997b5ec7d3f7f8fc94',
    url: 'https://get.com/core.tar'
  }
  const versionNotExisting = {
    hash: '0xc5555c79d6eccdcdd670d25997b5ec7d3f7f8fc94',
    url: 'https://notFound.com/core.tar'
  }
  let marketplace = null

  describe('contract ownership', async () => {
    before(async () => {
      marketplace = await Marketplace.new({ from: contractOwner })
    })

    it('original owner should have the ownership', async () => {
      assert.isTrue(await marketplace.isOwner({ from: contractOwner }))
    })

    it('other should not have the ownership', async () => {
      assert.isFalse(await marketplace.isOwner({ from: other }))
    })

    it('should transfer ownership', async () => {
      const tx = await marketplace.transferOwnership(contractOwner2, { from: contractOwner })
      truffleAssert.eventEmitted(tx, 'OwnershipTransferred')
    })

    it('original owner should not have the ownership', async () => {
      assert.isFalse(await marketplace.isOwner({ from: contractOwner }))
    })

    it('new owner should have the ownership', async () => {
      assert.isTrue(await marketplace.isOwner({ from: contractOwner2 }))
    })
  })

  describe('contract pauser', async () => {
    before(async () => {
      marketplace = await Marketplace.new({ from: contractOwner })
    })

    it('original owner should be pauser', async () => {
      assert.isTrue(await marketplace.isPauser(contractOwner))
    })

    it('other should not be pauser', async () => {
      assert.isFalse(await marketplace.isPauser(other))
    })

    it('should add pauser role', async () => {
      const tx = await marketplace.addPauser(contractOwner2, { from: contractOwner })
      truffleAssert.eventEmitted(tx, 'PauserAdded')
    })

    it('should remove pauser role', async () => {
      const tx = await marketplace.renouncePauser({ from: contractOwner })
      truffleAssert.eventEmitted(tx, 'PauserRemoved')
    })

    it('previous owner should not be pauser', async () => {
      assert.isFalse(await marketplace.isPauser(contractOwner))
    })

    it('new owner should be pauser', async () => {
      assert.isTrue(await marketplace.isPauser(contractOwner2))
    })
  })

  describe('pause contract', async () => {
    before(async () => {
      marketplace = await Marketplace.new()
    })

    it('should pause', async () => {
      assert.equal(await marketplace.paused(), false)
      const tx = await marketplace.pause({ from: contractOwner })
      truffleAssert.eventEmitted(tx, 'Paused')
      assert.equal(await marketplace.paused(), true)
    })

    it('should unpause', async () => {
      assert.equal(await marketplace.paused(), true)
      const tx = await marketplace.unpause({ from: contractOwner })
      truffleAssert.eventEmitted(tx, 'Unpaused')
      assert.equal(await marketplace.paused(), false)
    })

    describe('test modifier whenNotPaused', async () => {
      before(async () => {
        await marketplace.pause({ from: contractOwner })
      })

      it('should not be able to transfer service ownership', async () => {
        await truffleAssert.reverts(marketplace.createService(asciiToHex(sid), price, { from: developer }))
      })
      it('should not be able to transfer service ownership', async () => {
        await truffleAssert.reverts(marketplace.transferServiceOwnership(0, other, { from: developer }))
      })
      it('should not be able to change service price', async () => {
        await truffleAssert.reverts(marketplace.changeServicePrice(0, price, { from: developer }))
      })
      it('should not be able to create a service version', async () => {
        await truffleAssert.reverts(marketplace.createServiceVersion(0, version.hash, asciiToHex(version.url), { from: developer }))
      })
    })
  })

  describe('marketplace', async () => {
    before(async () => {
      marketplace = await Marketplace.new()
    })

    describe('service creation', async () => {
      it('should create a service', async () => {
        const tx = await marketplace.createService(asciiToHex(sid), price, { from: developer })
        assertEventServiceCreated(tx, 0, sid, price, developer)
      })

      it('should have one service', async () => {
        const serviceIndex = await marketplace.getServiceIndex(asciiToHex(sid))
        const service = await marketplace.services(serviceIndex)
        assertService(service, sid, price, developer)
      })

      it('should not be able to create a service with existing sid', async () => {
        await truffleAssert.reverts(marketplace.createService(asciiToHex(sid), price, { from: developer2 }), errorServiceSidAlreadyUsed)
      })

      it('should fail when getting service with not existing sid', async () => {
        await truffleAssert.reverts(marketplace.getServiceIndex(asciiToHex(sidNotExist)), errorServiceNotFound)
      })
    })

    describe('service price', async () => {
      it('should change service price', async () => {
        const tx = await marketplace.changeServicePrice(0, price2, { from: developer })
        assertEventServicePriceChanged(tx, 0, sid, price, price2)
      })

      it('should have changed service price', async () => {
        assert.equal(await marketplace.getServicesCount(), 1)
        const service = await marketplace.services(0)
        assertService(service, sid, price2, developer)
      })
    })

    describe('service version', async () => {
      it('should create a version', async () => {
        const tx = await marketplace.createServiceVersion(0, version.hash, asciiToHex(version.url), { from: developer })
        assertEventServiceVersionCreated(tx, 0, version.hash, version.url)
      })

      it('should have one version', async () => {
        assert.equal(await marketplace.getServiceVersionsCount(0), 1)
        const _version = await marketplace.getServiceVersion(0, 0)
        assertServiceVersion(_version, version.hash, version.url)
      })

      it('should create an other version', async () => {
        const tx = await marketplace.createServiceVersion(0, version2.hash, asciiToHex(version2.url), { from: developer })
        assertEventServiceVersionCreated(tx, 0, version2.hash, version2.url)
      })

      it('should have two version', async () => {
        assert.equal(await marketplace.getServiceVersionsCount(0), 2)
        // check version
        const _version = await marketplace.getServiceVersion(0, 0)
        assertServiceVersion(_version, version.hash, version.url)
        // check version2
        const _version2 = await marketplace.getServiceVersion(0, 1)
        assertServiceVersion(_version2, version2.hash, version2.url)
      })

      it('should not be able to create a version with same hash', async () => {
        await truffleAssert.reverts(marketplace.createServiceVersion(0, version2.hash, asciiToHex(version2.url), { from: developer }), errorServiceVersionHashAlreadyExist)
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
        const tx = await marketplace.pay(0, { from: purchaser, value: price2 })
        assertEventServicePaid(tx, 0, sid, price2, purchaser)
      })

      it('should have paid service', async () => {
        assert.equal(await marketplace.hasPaid(0, { from: purchaser }), true)
        const _payment = await marketplace.getServicePayment(0, 0)
        assertServicePayment(_payment, purchaser)
      })

      it('should not be able to pay twice the same service', async () => {
        await truffleAssert.reverts(marketplace.pay(0, { from: purchaser, value: price2 }), errorServicePaymentAlreadyPaid)
      })

      it('should not be able to pay with a wrong price', async () => {
        await truffleAssert.reverts(marketplace.pay(0, { from: purchaser2, value: price }), errorServicePaymentWrongPrice)
      })

      it('should fail when getting service payment with not existing purchaser', async () => {
        await truffleAssert.reverts(marketplace.getServicePaymentIndex(0, other), errorServicePaymentNotFound)
      })
    })

    describe('service ownership', async () => {
      it('original owner should have the service ownership', async () => {
        assert.equal(await marketplace.getServicesCount(), 1)
        assert.isTrue(await marketplace.isServiceOwner(0, { from: developer }))
      })

      it('other should not have the service ownership', async () => {
        assert.equal(await marketplace.getServicesCount(), 1)
        assert.isFalse(await marketplace.isServiceOwner(0, { from: other }))
      })

      it('should transfer service ownership', async () => {
        const tx = await marketplace.transferServiceOwnership(0, developer2,
          { from: developer }
        )
        assertEventServiceOwnershipTransferred(tx, 0, sid, developer, developer2)
      })

      it('new service owner should have the service ownership', async () => {
        assert.equal(await marketplace.getServicesCount(), 1)
        assert.isTrue(await marketplace.isServiceOwner(0, { from: developer2 }))
      })

      it('original owner should not have the service ownership', async () => {
        assert.equal(await marketplace.getServicesCount(), 1)
        assert.isFalse(await marketplace.isServiceOwner(0, { from: developer }))
      })

      describe('test modifier onlyServiceOwner', async () => {
        it('original owner should not be able to transfer service ownership', async () => {
          await truffleAssert.reverts(marketplace.transferServiceOwnership(0, other, { from: developer }), errorServiceOwner)
        })
        it('original owner should not be able to change service price', async () => {
          await truffleAssert.reverts(marketplace.changeServicePrice(0, price, { from: developer }), errorServiceOwner)
        })
        it('original owner should not be able to create a service version', async () => {
          await truffleAssert.reverts(marketplace.createServiceVersion(0, version.hash, asciiToHex(version.url), { from: developer }), errorServiceOwner)
        })
      })
    })
  })
})
