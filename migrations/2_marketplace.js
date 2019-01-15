/* global artifacts */

const Marketplace = artifacts.require('./Marketplace.sol')
const Token = artifacts.require('./Token.sol')

module.exports = async (deployer) => {
  await deployer.deploy(Token, 'MESG Token', 'MESG', 18, 250000000)
  await deployer.deploy(Marketplace, Token.address)
}
