/* eslint-env mocha */
/* global web3, contract, artifacts */

const Marketplace = artifacts.require('Marketplace')
const assert = require('chai').assert
const truffleAssert = require('truffle-assertions')

const toAscii = x => web3.utils.toAscii(x).replace(/\u0000/g, '')
const fromAscii = x => web3.utils.fromAscii(x)
const toNumber = x => web3.utils.toDecimal(x)

contract('Marketplace', async accounts => {
  const [
    contractOwner,
    contractOwner2,
    developer,
    developer2,
    purchaser
  ] = accounts
  let marketplace = null

  describe('contract ownership', async () => {
    before(async () => {
      marketplace = await Marketplace.new({ from: contractOwner })
    })

    it('original owner should have the ownership', async () => {
      assert.equal(await marketplace.owner.call(), contractOwner)
      assert.equal(await marketplace.isPauser.call(contractOwner), true)
    })

    it('should add pauser role', async () => {
      const tx = await marketplace.addPauser(contractOwner2, { from: contractOwner })
      truffleAssert.eventEmitted(tx, 'PauserAdded')
    })

    it('should remove pauser role', async () => {
      const tx = await marketplace.renouncePauser({ from: contractOwner })
      truffleAssert.eventEmitted(tx, 'PauserRemoved')
    })

    it('should transfer ownership', async () => {
      const tx = await marketplace.transferOwnership(contractOwner2, { from: contractOwner })
      truffleAssert.eventEmitted(tx, 'OwnershipTransferred')
    })

    it('new owner should have the ownership', async () => {
      assert.equal(await marketplace.owner.call(), contractOwner2)
      assert.equal(await marketplace.isPauser.call(contractOwner2), true)
    })
  })

  describe('pause contract', async () => {
    before(async () => {
      marketplace = await Marketplace.new()
    })

    it('should pause', async () => {
      assert.equal(await marketplace.paused(), false)
      const tx = await marketplace.pause({ from: contractOwner })
      truffleAssert.eventEmitted(tx, 'Paused')
      assert.equal(await marketplace.paused(), true)
    })

    it('should unpause', async () => {
      assert.equal(await marketplace.paused(), true)
      const tx = await marketplace.unpause({ from: contractOwner })
      truffleAssert.eventEmitted(tx, 'Unpaused')
      assert.equal(await marketplace.paused(), false)
    })
  })

  describe('service', async () => {
    before(async () => {
      marketplace = await Marketplace.new()
    })

    it('should create a service', async () => {
      const sid = 'test-create-service'
      const tx = await marketplace.createService(sid,
        { from: developer }
      )
      truffleAssert.eventEmitted(tx, 'ServiceCreated')
      assert.equal(await marketplace.getServicesCount(), 1)
      const service = await marketplace.services.call(0)
      assert.equal(service.owner, developer)
      assert.equal(service.sid, sid)
    })
  })

  // it("should change service owner", async () => {
  //   const sid = "test-create-service"
  //   const tx = await marketplace.changeServiceOwner(sid, developer2, { from: developer })
  //   // assert.equal(await service.owner.call(), developer)
  //   // assert.equal(await service.isPauser.call(deployer), false)
  //   // assert.equal(await service.isPauser.call(developer), true)
  //   // assert.equal(toAscii(await service.sid.call()), sid)
  // })
})

// contract("Marketplace", async (accounts: string[]) => {

//   const [deployer, developer, buyer] = accounts
//   let marketplace = null
//   beforeEach(async () => {
//     marketplace = await Marketplace.deployed()
//   })

//   it("should have the right ownership", async () => {
//     assert.equal(await marketplace.owner.call(), deployer)
//     assert.equal(await marketplace.isPauser.call(deployer), true)
//   })

//   it("should create a service", async () => {
//     const sid = "test-create-service"
//     const service = await deployService(marketplace, sid, developer)
//     assert.equal(await service.owner.call(), developer)
//     assert.equal(await service.isPauser.call(deployer), false)
//     assert.equal(await service.isPauser.call(developer), true)
//     assert.equal(toAscii(await service.sid.call()), sid)
//   })

//   it("should pause the marketplace", async () => {
//     const sid = "test-pause-marketplace"
//     await pause(marketplace, deployer)
//     const bytesSid = web3.utils.fromAscii(sid)
//     await truffleAssert.reverts(marketplace.createService(
//       bytesSid,
//       { from: developer }
//     ))
//   })
// })

// contract("Service", async accounts => {
//   const [developer, buyer, buyer2] = accounts
//   let service = null
//   let sid = null
//   beforeEach(async () => {
//     const marketplace = await Marketplace.deployed()
//     sid = (Math.random() * 100).toString()
//     service = await deployService(marketplace, sid, developer)
//   })

//   it("should have the right ownership", async () => {
//     assert.equal(await service.owner.call(), developer)
//     assert.equal(await service.isPauser.call(developer), true)
//     assert.equal(toAscii(await service.sid.call()), sid)
//   })

//   it("should create a version", async () => {
//     const tx = await service.createVersion(
//       fromAscii("a"),
//       fromAscii("..."),
//       10,
//       { from: developer }
//     )
//     truffleAssert.eventEmitted(tx, 'VersionCreated', async event => {
//       assert.equal(toAscii(event.sid), sid)
//       assert.equal(toAscii(event.id), "a")
//       assert.equal(event.id, await service.latest.call())

//       const version = await service.versions.call(event.id)
//       assert.equal(event.id, version.id)
//       assert.equal("...", toAscii(version.location))
//       assert.equal(10, toNumber(version.price))
//     })
//     assert.equal(await service.owner.call(), developer)
//     assert.equal(await service.isPauser.call(developer), true)
//     assert.equal(toAscii(await service.sid.call()), sid)
//   })

//   it("shoulnt create a version", async () => {
//     await truffleAssert.passes(service.createVersion(
//       fromAscii("a"),
//       fromAscii("..."),
//       10,
//       { from: developer }
//     ))
//     await truffleAssert.reverts(service.createVersion(
//       fromAscii("a"),
//       fromAscii("..."),
//       10,
//       { from: developer }
//     ))

//     await truffleAssert.reverts(service.createVersion(
//       fromAscii("b"),
//       fromAscii("..."),
//       10,
//       { from: buyer }
//     ))
//     await pause(service, developer)
//     await truffleAssert.reverts(service.createVersion(
//       fromAscii("b"),
//       fromAscii("..."),
//       10,
//       { from: developer }
//     ))
//   })

//   it("should request access", async () => {
//     assert.equal(await service.hasAccessToVersion.call(fromAscii("a"), buyer), false)
//     await truffleAssert.passes(service.createVersion(
//       fromAscii("a"),
//       fromAscii("..."),
//       10,
//       { from: developer }
//     ))
//     assert.equal(await service.hasAccessToVersion.call(fromAscii("a"), buyer), false)
//     await truffleAssert.passes(service.requestAccess(
//       fromAscii("a"),
//       { from: buyer }
//     ))
//     assert.equal(await service.hasAccessToVersion.call(fromAscii("a"), buyer), true)
//     await truffleAssert.reverts(service.requestAccess(
//       fromAscii("a"),
//       { from: buyer }
//     ))
//     assert.equal(await service.hasAccessToVersion.call(fromAscii("a"), buyer2), false)
//     await pause(service, developer)
//     await truffleAssert.reverts(service.requestAccess(
//       fromAscii("a"),
//       { from: buyer2 }
//     ))
//     assert.equal(await service.hasAccessToVersion.call(fromAscii("a"), buyer2), false)
//   })
// })
