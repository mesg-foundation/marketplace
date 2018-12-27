module.exports = ({ contract, web3 }) => async (_, { success, error }) => {
  try {
    const total = await contract.methods.totalServices().call()
    return success({
      total: web3.utils.hexToNumber(total)
    })
  } catch(e) {
    return error({ error: e.toString() })
  }
}
