module.exports = ({ MESG, contract, account, web3 }) => async ({ sid, hash, location, price }, { success, error }) => {
  try {
    console.log(account, account.address)
    let serviceAddr = await contract.methods.services(web3.utils.fromAscii(sid)).call({ from: account.address })
    console.log(1)
    if (!serviceAddr) {
      console.log(2)
      const signedTransaction = await account.signTransaction({
        to: contract.options.address,
        data: contract.methods.createService(web3.utils.fromAscii(sid)).encodeABI(),
        gas: 1200000,
        value: 0,
        gasPrice: await web3.eth.getGasPrice()
      })
      console.log(3, signTransaction)
      const receipt = await new Promise((resolve, reject) => web3.eth.sendSignedTransaction(signedTransaction.rawTransaction)
        .on('receipt', resolve)
        .on('error', reject)
      )
      console.log(4, receipt)
      serviceAddr = receipt
    }

    console.log(5)
    const signedTransaction = await account.signTransaction({
      to: service.options.address,
      data: contract.methods.createService(web3.utils.fromAscii(sid)).encodeABI(),
      gas: 1200000,
      value: 0,
      gasPrice: await web3.eth.getGasPrice()
    })
    console.log(6, signTransaction)
    const receipt = await new Promise((resolve, reject) => web3.eth.sendSignedTransaction(signedTransaction.rawTransaction)
      .on('receipt', resolve)
      .on('error', reject)
    )
    console.log(7, receipt)
    return success({
      sid: receipt.sid,
      hash: receipt.hash,
      location: receipt.location
    })
  } catch (e) {
    return error({ error: e.toString() })
  }
}

