/* global artifacts */

const web3 = require('web3')
const Token = artifacts.require('MESGToken')

const tokenTestConfig = {
  name: 'MESG Test',
  symbol: 'MESG Test',
  decimals: 18,
  totalSupply: 100000000
}

const newDefaultToken = async (owner) => {
  const contract = await Token.new(tokenTestConfig.name, tokenTestConfig.symbol, tokenTestConfig.decimals, tokenTestConfig.totalSupply, { from: owner })
  console.log('new token contract deployed at', contract.address)
  return contract
}

const BN = x => new web3.utils.BN(x)

module.exports = {
  Token,
  newDefaultToken,
  tokenTestConfig,
  BN,
  hexToAscii: x => web3.utils.hexToAscii(x).replace(/\u0000/g, ''),
  asciiToHex: x => web3.utils.asciiToHex(x)
}
