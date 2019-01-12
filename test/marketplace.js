/* eslint-env mocha */
/* global contract, artifacts */

const Marketplace = artifacts.require('Marketplace')
const assert = require('chai').assert
const truffleAssert = require('truffle-assertions')
const web3 = require('web3')

const hexToAscii = x => web3.utils.hexToAscii(x).replace(/\u0000/g, '')
const padRight = x => web3.utils.padRight(x, 64)
const asciiToHex = x => web3.utils.asciiToHex(x)
const hexToNumber = x => web3.utils.hexToNumber(x)
const BN = x => new web3.utils.BN(x)
const isBN = x => web3.utils.isBN(x)

contract('Marketplace', async accounts => {
  const [
    contractOwner,
    contractOwner2,
    developer,
    developer2,
    purchaser,
    purchaser2
  ] = accounts
  let marketplace = null

  describe('contract ownership', async () => {
    before(async () => {
      marketplace = await Marketplace.new({ from: contractOwner })
    })

    it('original owner should have the ownership', async () => {
      assert.equal(await marketplace.owner.call(), contractOwner)
      assert.equal(await marketplace.isPauser.call(contractOwner), true)
    })

    it('should add pauser role', async () => {
      const tx = await marketplace.addPauser(contractOwner2, { from: contractOwner })
      truffleAssert.eventEmitted(tx, 'PauserAdded')
    })

    it('should remove pauser role', async () => {
      const tx = await marketplace.renouncePauser({ from: contractOwner })
      truffleAssert.eventEmitted(tx, 'PauserRemoved')
    })

    it('should transfer ownership', async () => {
      const tx = await marketplace.transferOwnership(contractOwner2, { from: contractOwner })
      truffleAssert.eventEmitted(tx, 'OwnershipTransferred')
    })

    it('new owner should have the ownership', async () => {
      assert.equal(await marketplace.owner.call(), contractOwner2)
      assert.equal(await marketplace.isPauser.call(contractOwner2), true)
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
  })

  describe('create service', async () => {
    const sid = 'test-create-service-0'
    const price = 1000000000
    const price2 = 2000000000
    const version = {
      hash: '0xa666c79d6eccdcdd670d25997b5ec7d3f7f8fc94',
      url: 'https://download.com/core.tar'
    }

    before(async () => {
      marketplace = await Marketplace.new()
    })

    it('should create a service', async () => {
      const tx = await marketplace.createService(asciiToHex(sid), price,
        { from: developer }
      )
      truffleAssert.eventEmitted(tx, 'ServiceCreated')
      const event = tx.logs[0].args
      assert.isTrue(isBN(event.serviceIndex))
      assert.isTrue(event.serviceIndex.eq(BN(0)))
      assert.equal(hexToAscii(event.sid), sid)
      assert.equal(event.owner, developer)
    })

    it('should have one service', async () => {
      assert.equal(await marketplace.getServicesCount(), 1)
      const service = await marketplace.services.call(0)
      assert.equal(service.owner, developer)
      assert.equal(hexToAscii(service.sid), sid)
      assert.equal(service.price, price)
    })

    it('should change service price', async () => {
      const tx = await marketplace.changeServicePrice(0, price2,
        { from: developer }
      )
      truffleAssert.eventEmitted(tx, 'ServicePriceChanged')
      const event = tx.logs[0].args
      assert.isTrue(isBN(event.serviceIndex))
      assert.isTrue(event.serviceIndex.eq(BN(0)))
      assert.equal(hexToAscii(event.sid), sid)
      assert.equal(event.previousPrice, price)
      assert.equal(event.newPrice, price2)
    })

    it('should have changed service price', async () => {
      assert.equal(await marketplace.getServicesCount(), 1)
      const service = await marketplace.services.call(0)
      assert.equal(service.owner, developer)
      assert.equal(hexToAscii(service.sid), sid)
      assert.equal(service.price, price2)
    })

    it('should create a version', async () => {
      const tx = await marketplace.createServiceVersion(0, version.hash, asciiToHex(version.url),
        { from: developer }
      )
      truffleAssert.eventEmitted(tx, 'ServiceVersionCreated')
      const event = tx.logs[0].args
      assert.isTrue(web3.utils.isBN(event.serviceIndex))
      assert.isTrue(event.serviceIndex.eq(BN(0)))
      assert.equal(event.hash, version.hash)
      assert.equal(hexToAscii(event.url), version.url)
    })

    it('should have one version', async () => {
      assert.equal(await marketplace.getServiceVersionsCount(0), 1)
      const _version = await marketplace.getServiceVersion(0, 0)
      assert.equal(_version.hash, version.hash)
      assert.equal(hexToAscii(_version.url), version.url)
    })

    it('should pay a service', async () => {
      const tx = await marketplace.pay(0,
        { from: purchaser, value: price2 }
      )
      truffleAssert.eventEmitted(tx, 'ServicePaid')
      const event = tx.logs[0].args
      assert.isTrue(web3.utils.isBN(event.serviceIndex))
      assert.isTrue(event.serviceIndex.eq(BN(0)))
      assert.equal(hexToAscii(event.sid), sid)
      assert.equal(event.purchaser, purchaser)
      assert.equal(event.price, price2)
    })

    it('should have paid service', async () => {
      assert.equal(await marketplace.hasPaid(0, {
        from: purchaser
      }), true)
      const _payment = await marketplace.getServicePayment(0, 0)
      assert.equal(_payment, purchaser)
    })

    it('should transfer service ownership', async () => {
      const tx = await marketplace.transferServiceOwnership(0, developer2,
        { from: developer }
      )
      truffleAssert.eventEmitted(tx, 'ServiceOwnershipTransferred')
      const event = tx.logs[0].args
      assert.isTrue(web3.utils.isBN(event.serviceIndex))
      assert.isTrue(event.serviceIndex.eq(BN(0)))
      assert.equal(hexToAscii(event.sid), sid)
      assert.equal(event.previousOwner, developer)
      assert.equal(event.newOwner, developer2)
    })
  })
})
