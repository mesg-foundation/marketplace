const { abi } = require("../Service.json")

const getOrCreateService = async (web3, contract, account, sid) => {
  const serviceAddr = await contract.methods.serviceContracts(web3.utils.fromAscii(sid)).call()
  if (serviceAddr) {
    return serviceAddr
  }
  const signedTransaction = await account.signTransaction({
    to: contract.options.address,
    data: contract.methods.createService(web3.utils.fromAscii(sid)).encodeABI(),
    gas: 1200000,
    value: 0,
    gasPrice: await web3.eth.getGasPrice()
  })
  const receipt = await new Promise((resolve, reject) => web3.eth.sendSignedTransaction(signedTransaction.rawTransaction)
    .on('receipt', resolve)
    .on('error', reject)
  )
  return receipt
}

module.exports = ({ contract, account, web3 }) => async ({ sid, hash, location, price }, { success, error }) => {
  try {
    const serviceAddr = await getOrCreateService(web3, contract, account, sid)
    const serviceContract = new web3.eth.Contract(abi, serviceAddr)
    const parameters = [
      web3.utils.fromAscii(hash),
      web3.utils.fromAscii(location),
      price
    ]
    const signedTransaction = await account.signTransaction({
      to: serviceAddr,
      data: serviceContract.methods.createVersion(...parameters).encodeABI(),
      gas: 1200000,
      value: 0,
      gasPrice: await web3.eth.getGasPrice()
    })
    await new Promise((resolve, reject) => web3.eth.sendSignedTransaction(signedTransaction.rawTransaction)
      .on('receipt', resolve)
      .on('error', reject)
    )
    return success({ sid, hash, location })
  } catch (e) {
    return error({ error: e.toString() })
  }
}

