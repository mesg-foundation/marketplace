const Marketplace = artifacts.require("Marketplace")
const Service = artifacts.require("Service")
const assert = require("chai").assert
const truffleAssert = require('truffle-assertions')

const toAscii = x => web3.utils.toAscii(x).replace(/\u0000/g, '')
const fromAscii = x => web3.utils.fromAscii(x)
const toNumber = x => web3.utils.toDecimal(x)
const pause = async (contract, from) => {
  const tx = await contract.pause(
    { from }
  )
  truffleAssert.eventEmitted(tx, 'Paused')
  return tx
}
const deployService = async (marketplace, sid, from) => {
  const bytesSid = fromAscii(sid)
  const serviceCount = toNumber(await marketplace.totalServices.call())
  const tx = await marketplace.createService(
    bytesSid,
    { from }
  )
  truffleAssert.eventEmitted(tx, 'ServiceCreated', async event => {
    assert.equal(toAscii(event.sid), sid)
    assert.equal(event.serviceAddress, await marketplace.serviceContracts.call(bytesSid))
    assert.equal(serviceCount + 1, toNumber(await marketplace.totalServices.call()))
    assert.equal(sid, toAscii(await marketplace.services.call(serviceCount)))
  })
  const serviceAddress = await marketplace.serviceContracts.call(bytesSid)
  return new Service(serviceAddress)
}

contract("Marketplace", async accounts => {

  const [deployer, developer, buyer] = accounts
  let marketplace = null
  beforeEach(async () => {
    marketplace = await Marketplace.deployed()
  })

  it("should have the right ownership", async () => {
    assert.equal(await marketplace.owner.call(), deployer)
    assert.equal(await marketplace.isPauser.call(deployer), true)
  })

  it("should create a service", async () => {
    const sid = "test-create-service"
    const service = await deployService(marketplace, sid, developer)
    assert.equal(await service.owner.call(), developer)
    assert.equal(await service.isPauser.call(deployer), false)
    assert.equal(await service.isPauser.call(developer), true)
    assert.equal(toAscii(await service.sid.call()), sid)
  })

  it("should pause the marketplace", async () => {
    const sid = "test-pause-marketplace"
    await pause(marketplace, deployer)
    const bytesSid = web3.utils.fromAscii(sid)
    await truffleAssert.reverts(marketplace.createService(
      bytesSid,
      { from: developer }
    ))
  })
})

contract("Service", async accounts => {
  const [developer, buyer, buyer2] = accounts
  let service = null
  let sid = null
  beforeEach(async () => {
    const marketplace = await Marketplace.deployed()
    sid = (Math.random() * 100).toString()
    service = await deployService(marketplace, sid, developer)
  })

  it("should have the right ownership", async () => {
    assert.equal(await service.owner.call(), developer)
    assert.equal(await service.isPauser.call(developer), true)
    assert.equal(toAscii(await service.sid.call()), sid)
  })

  it("should create a version", async () => {
    const tx = await service.createVersion(
      fromAscii("a"),
      fromAscii("..."),
      10,
      { from: developer }
    )
    truffleAssert.eventEmitted(tx, 'VersionCreated', async event => {
      assert.equal(toAscii(event.sid), sid)
      assert.equal(toAscii(event.id), "a")
      assert.equal(event.id, await service.latest.call())
      
      const version = await service.versions.call(event.id)
      assert.equal(event.id, version.id)
      assert.equal("...", toAscii(version.location))
      assert.equal(10, toNumber(version.price))
    })
    assert.equal(await service.owner.call(), developer)
    assert.equal(await service.isPauser.call(developer), true)
    assert.equal(toAscii(await service.sid.call()), sid)
  })

  it("shoulnt create a version", async () => {
    await truffleAssert.passes(service.createVersion(
      fromAscii("a"),
      fromAscii("..."),
      10,
      { from: developer }
    ))
    await truffleAssert.reverts(service.createVersion(
      fromAscii("a"),
      fromAscii("..."),
      10,
      { from: developer }
    ))

    await truffleAssert.reverts(service.createVersion(
      fromAscii("b"),
      fromAscii("..."),
      10,
      { from: buyer }
    ))
    await pause(service, developer)
    await truffleAssert.reverts(service.createVersion(
      fromAscii("b"),
      fromAscii("..."),
      10,
      { from: developer }
    ))
  })

  it("should request access", async () => {
    assert.equal(await service.hasAccessToVersion.call(fromAscii("a"), buyer), false)
    await truffleAssert.passes(service.createVersion(
      fromAscii("a"),
      fromAscii("..."),
      10,
      { from: developer }
    ))
    assert.equal(await service.hasAccessToVersion.call(fromAscii("a"), buyer), false)
    await truffleAssert.passes(service.requestAccess(
      fromAscii("a"),
      { from: buyer }
    ))
    assert.equal(await service.hasAccessToVersion.call(fromAscii("a"), buyer), true)
    await truffleAssert.reverts(service.requestAccess(
      fromAscii("a"),
      { from: buyer }
    ))
    assert.equal(await service.hasAccessToVersion.call(fromAscii("a"), buyer2), false)
    await pause(service, developer)
    await truffleAssert.reverts(service.requestAccess(
      fromAscii("a"),
      { from: buyer2 }
    ))
    assert.equal(await service.hasAccessToVersion.call(fromAscii("a"), buyer2), false)
  })
})