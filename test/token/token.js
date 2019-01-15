/* eslint-env mocha */
/* global contract, artifacts */

const assert = require('chai').assert
const utils = require('../utils')
const Token = artifacts.require('Token')

const name = 'MESG Token'
const symbol = 'MESG'
const decimals = 18
const totalSupply = 250000000
const calculatedTotalSupply = utils.BN(totalSupply).mul(utils.BN(10).pow(utils.BN(decimals)))
const newDefaultToken = (owner) => Token.new(name, symbol, decimals, totalSupply, { from: owner })

module.exports = { name, symbol, decimals, totalSupply, newDefaultToken }

contract('Token', async ([ contractOwner, other ]) => {
  let token = null

  before(async () => {
    token = await newDefaultToken(contractOwner)
  })

  it('should have the right supply', async () => {
    assert.isTrue((await token.totalSupply()).eq(calculatedTotalSupply))
  })

  it('should have the right name', async () => {
    assert.equal(await token.name(), name)
  })

  it('should have the right symbol', async () => {
    assert.equal(await token.symbol(), symbol)
  })

  it('should have the right decimals', async () => {
    assert.equal(await token.decimals(), decimals)
  })

  it('creator should have all the supply', async () => {
    const balanceOf = await token.balanceOf(contractOwner)
    assert.isTrue(balanceOf.eq(calculatedTotalSupply))
  })

  it('other should have 0 token', async () => {
    const balanceOf = await token.balanceOf(other)
    assert.isTrue(balanceOf.eq(utils.BN(0)))
  })
})
