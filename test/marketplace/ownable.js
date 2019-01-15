/* eslint-env mocha */
/* global contract, artifacts */

const assert = require('chai').assert
const truffleAssert = require('truffle-assertions')

const Marketplace = artifacts.require('Marketplace')
const { newDefaultToken } = require('../token/token')

contract('Marketplace Ownable', async accounts => {
  const [
    originalOwner,
    newOwner,
    other
  ] = accounts

  let contract = null

  before(async () => {
    const token = await newDefaultToken(originalOwner)
    contract = await Marketplace.new(token.address, { from: originalOwner })
  })

  it('original owner should have the ownership', async () => {
    assert.isTrue(await contract.isOwner({ from: originalOwner }))
  })

  it('other should not have the ownership', async () => {
    assert.isFalse(await contract.isOwner({ from: other }))
  })

  it('should transfer ownership', async () => {
    const tx = await contract.transferOwnership(newOwner, { from: originalOwner })
    truffleAssert.eventEmitted(tx, 'OwnershipTransferred')
  })

  it('original owner should not have the ownership', async () => {
    assert.isFalse(await contract.isOwner({ from: originalOwner }))
  })

  it('new owner should have the ownership', async () => {
    assert.isTrue(await contract.isOwner({ from: newOwner }))
  })
})
