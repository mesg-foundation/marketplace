/* eslint-env mocha */
/* global contract, artifacts */

const Marketplace = artifacts.require('Marketplace')
const assert = require('chai').assert
const truffleAssert = require('truffle-assertions')
const web3 = require('web3')

const hexToAscii = x => web3.utils.hexToAscii(x).replace(/\u0000/g, '')
const padRight = x => web3.utils.padRight(x, 64)
const asciiToHex = x => web3.utils.asciiToHex(x)
const hexToNumber = x => web3.utils.hexToNumber(x)
const BN = x => new web3.utils.BN(x)
const isBN = x => web3.utils.isBN(x)

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

  describe('create service', async () => {
    const sid = 'test-create-service-0'
    const price = 1000000000
    const version = {
      hash: '0xa666c79d6eccdcdd670d25997b5ec7d3f7f8fc94',
      url: 'https://download.com/core.tar'
    }

    before(async () => {
      marketplace = await Marketplace.new()
    })

    it('should create a service', async () => {
      const tx = await marketplace.createService(asciiToHex(sid), price,
        { from: developer }
      )
      truffleAssert.eventEmitted(tx, 'ServiceCreated')
      const event = tx.logs[0].args
      assert.isTrue(isBN(event.serviceIndex))
      assert.isTrue(event.serviceIndex.eq(BN(0)))
      // assert.isTrue(event.serviceIndex.eq(0))
      assert.equal(event.owner, developer)
    })

    it('should have one service', async () => {
      assert.equal(await marketplace.getServicesCount(), 1)
      const service = await marketplace.services.call(0)
      assert.equal(service.owner, developer)
      assert.equal(hexToAscii(service.sid), sid)
      assert.equal(service.price, price)
    })

    it('should create a version', async () => {
      const tx = await marketplace.createServiceVersion(0, version.hash, asciiToHex(version.url),
        { from: developer }
      )

      truffleAssert.eventEmitted(tx, 'ServiceVersionCreated')
      const event = tx.logs[0].args
      assert.isTrue(web3.utils.isBN(event.serviceIndex))
      assert.isTrue(event.serviceIndex.eq(BN(0)))
      assert.equal(event.hash, version.hash)
      assert.equal(hexToAscii(event.url), version.url)
    })

    it('should have one version', async () => {
      assert.equal(await marketplace.getServiceVersionsCount(0), 1)
      const _version = await marketplace.getVersion(0, 0)
      assert.equal(_version.hash, version.hash)
      assert.equal(hexToAscii(_version.url), version.url)
    })
  })

  // it("should transfer service ownership", async () => {
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
