const web3 = require('web3')

const tokenTestConfig = {
  name: 'MESG Test',
  symbol: 'MESG Test',
  decimals: 18,
  totalSupply: 100000000
}

const newDefaultToken = async (Token, owner) => {
  const contract = await Token.new(tokenTestConfig.name, tokenTestConfig.symbol, tokenTestConfig.decimals, tokenTestConfig.totalSupply, { from: owner })
  console.log('new token contract deployed at', contract.address)
  return contract
}

module.exports = {
  newDefaultToken,
  tokenTestConfig,
  BN: x => new web3.utils.BN(x),
  hexToAscii: x => web3.utils.hexToAscii(x).replace(/\u0000/g, ''),
  asciiToHex: x => web3.utils.asciiToHex(x),
  asciiToHex32: x => web3.utils.asciiToHex(x),
  sleep: ms => new Promise(resolve => setTimeout(resolve, ms))
}
