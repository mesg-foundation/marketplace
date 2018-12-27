const Web3 = require('web3')
const MESG = require('mesg-js').service()

const web3 = new Web3(new Web3.providers.WebsocketProvider(process.env.ENDPOINT))
const abi = require('./Marketplace.json').abi
const contract = new web3.eth.Contract(abi, process.env.MARKETPLACE_ADDRESS)

contract.events.ServiceCreated((err, event) => err
  ? console.error(err)
  : MESG.emitEvent("serviceCreated", {
    sid: web3.utils.toAscii(event.returnValues.sid),
    address: event.returnValues.serviceAddress
  })
)

MESG.listenTask(require('./tasks')({
  MESG,
  web3,
  contract,
  account: web3.eth.accounts.privateKeyToAccount(process.env.PRIVATE_KEY)
}))
