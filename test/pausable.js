/* eslint-env mocha */
/* global contract, artifacts */

const assert = require('chai').assert
const truffleAssert = require('truffle-assertions')
const { Token, asciiToHex } = require('./utils')

const Marketplace = artifacts.require('Marketplace')
const { sid, version, price } = require('./marketplace')

contract('Marketplace Pausable', async accounts => {
  const [
    originalOwner,
    newOwner,
    developer,
    other
  ] = accounts

  let contract = null

  describe('Marketplace Pauser role', async () => {
    before(async () => {
      const token = await Token.deployed()
      contract = await Marketplace.new(token.address, { from: originalOwner })
    })

    it('original owner should be pauser', async () => {
      assert.isTrue(await contract.isPauser(originalOwner))
    })

    it('other should not be pauser', async () => {
      assert.isFalse(await contract.isPauser(other))
    })

    it('should add pauser role', async () => {
      const tx = await contract.addPauser(newOwner, { from: originalOwner })
      truffleAssert.eventEmitted(tx, 'PauserAdded')
    })

    it('should remove pauser role', async () => {
      const tx = await contract.renouncePauser({ from: originalOwner })
      truffleAssert.eventEmitted(tx, 'PauserRemoved')
    })

    it('previous owner should not be pauser', async () => {
      assert.isFalse(await contract.isPauser(originalOwner))
    })

    it('new owner should be pauser', async () => {
      assert.isTrue(await contract.isPauser(newOwner))
    })
  })

  describe('Marketplace Pause contract', async () => {
    before(async () => {
      const token = await Token.deployed()
      contract = await Marketplace.new(token.address, { from: originalOwner })
    })

    it('should pause', async () => {
      assert.equal(await contract.paused(), false)
      const tx = await contract.pause({ from: originalOwner })
      truffleAssert.eventEmitted(tx, 'Paused')
      assert.equal(await contract.paused(), true)
    })

    it('should unpause', async () => {
      assert.equal(await contract.paused(), true)
      const tx = await contract.unpause({ from: originalOwner })
      truffleAssert.eventEmitted(tx, 'Unpaused')
      assert.equal(await contract.paused(), false)
    })

    describe('Marketplace Test modifier whenNotPaused', async () => {
      before(async () => {
        await contract.pause({ from: originalOwner })
      })

      it('should not be able to transfer service ownership', async () => {
        await truffleAssert.reverts(contract.createService(asciiToHex(sid), price, { from: developer }))
      })
      it('should not be able to transfer service ownership', async () => {
        await truffleAssert.reverts(contract.transferServiceOwnership(0, other, { from: developer }))
      })
      it('should not be able to change service price', async () => {
        await truffleAssert.reverts(contract.changeServicePrice(0, price, { from: developer }))
      })
      it('should not be able to create a service version', async () => {
        await truffleAssert.reverts(contract.createServiceVersion(0, version.hash, asciiToHex(version.url), { from: developer }))
      })
    })
  })
})
