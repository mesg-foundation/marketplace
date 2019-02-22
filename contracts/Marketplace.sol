pragma solidity >=0.5.0 <0.6.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "./BytesUtils.sol";
import "./DnsUtils.sol";

contract Marketplace is Ownable, Pausable {
  using BytesUtils for bytes;
  using DnsUtils for bytes;

  /**
    Structures
   */

  struct Service {
    uint256 createTime;
    address owner;
    bytes sid;

    mapping(bytes32 => Version) versions; // version's hash => Version
    bytes32[] versionsList;

    Offer[] offers;

    mapping(address => Purchase) purchases; // purchaser's address => Purchase
    address[] purchasesList;
  }

  struct Purchase {
    uint256 createTime;
    uint expire;
  }

  struct Version {
    uint256 createTime;
    bytes manifest;
    bytes manifestProtocol;
  }

  struct Offer {
    uint256 createTime;
    uint price;
    uint duration;
    bool active;
  }

  /**
    Constant
   */

  uint constant INFINITY = ~uint256(0);
  uint constant MAX_SID_LENGTH = 63;


  /**
    State variables
   */

  IERC20 public token;

  mapping(bytes32 => Service) public services; // service's hashed sid => Service
  bytes32[] public servicesList;

  mapping(bytes32 => bytes32) public hashToService; // version's hash => service's hashed sid

  /**
    Constructor
   */

  constructor(IERC20 _token) public {
    token = _token;
  }

  /**
    Events
   */

  event ServiceCreated(
    bytes sid,
    bytes32 indexed sidHash,
    address indexed owner
  );

  event ServiceOwnershipTransferred(
    bytes32 indexed sidHash,
    address indexed previousOwner,
    address indexed newOwner
  );

  event ServiceVersionCreated(
    bytes32 indexed sidHash,
    bytes32 indexed hash,
    bytes manifest,
    bytes manifestProtocol
  );

  event ServiceOfferCreated(
    bytes32 indexed sidHash,
    uint indexed offerIndex,
    uint price,
    uint duration
  );

  event ServiceOfferDisabled(
    bytes32 indexed sidHash,
    uint indexed offerIndex
  );

  event ServicePurchased(
    bytes32 indexed sidHash,
    uint indexed offerIndex,
    address indexed purchaser,
    uint price,
    uint duration,
    uint expire
  );

  /**
    Modifiers
   */

  modifier whenAddressNotZero(address a) {
    require(a != address(0), "Address cannot be set to zero");
    _;
  }

  modifier whenManifestNotEmpty(bytes memory manifest) {
    require(!manifest.isZero(), "Manifest cannot be empty");
    _;
  }

  modifier whenManifestProtocolNotEmpty(bytes memory manifestProtocol) {
    require(!manifestProtocol.isZero(), "Manifest protocol cannot be empty");
    _;
  }

  modifier whenDurationNotZero(uint duration) {
    require(duration > 0, "Duration cannot be zero");
    _;
  }

  modifier whenServiceExist(bytes32 sid) {
    require(isServiceExist(sid), "Service with this sid does not exist");
    _;
  }

  modifier onlyServiceOwner(bytes32 sidHash) {
    require(services[sidHash].owner == msg.sender, "Service owner is not the sender");
    _;
  }

  modifier notServiceOwner(bytes32 sidHash) {
    require(services[sidHash].owner != msg.sender, "Service owner cannot be the sender");
    _;
  }

  modifier whenServiceHashNotExist(bytes32 hash) {
    require(services[hashToService[hash]].owner == address(0), "Hash already exists");
    _;
  }

  modifier whenServiceVersionNotEmpty(bytes32 sidHash) {
    require(services[sidHash].versionsList.length > 0, "Cannot create an offer on a service without version");
    _;
  }

  modifier whenServiceOfferExist(bytes32 sid, uint offerIndex) {
    require(isServiceOfferExist(sid, offerIndex), "Service offer does not exist");
    _;
  }

  modifier whenServiceOfferActive(bytes32 sidHash, uint offerIndex) {
    require(services[sidHash].offers[offerIndex].active, "Service offer is not active");
    _;
  }

  /**
    Externals
   */

  function createService(bytes calldata sid)
    external
    whenNotPaused
  {
    require(sid.length > 0, "Sid cannot be empty");
    require(sid.length <= MAX_SID_LENGTH, "Sid cannot exceed 63 chars");
    require(sid.isDomainName(), "Sid format invalid");
    bytes32 sidHash = keccak256(sid);
    require(services[sidHash].owner == address(0), "Service with same sid already exists");
    services[sidHash].owner = msg.sender;
    services[sidHash].sid = sid;
    services[sidHash].createTime = now;
    servicesList.push(sidHash);
    emit ServiceCreated(sid, sidHash, msg.sender);
  }

  function transferServiceOwnership(bytes32 sidHash, address newOwner)
    external
    whenNotPaused
    onlyServiceOwner(sidHash)
    whenAddressNotZero(newOwner)
  {
    emit ServiceOwnershipTransferred(sidHash, services[sidHash].owner, newOwner);
    services[sidHash].owner = newOwner;
  }

  function createServiceVersion(
    bytes32 sidHash,
    bytes32 hash,
    bytes calldata manifest,
    bytes calldata manifestProtocol
  )
    external
    whenNotPaused
    onlyServiceOwner(sidHash)
    whenServiceHashNotExist(hash)
    whenManifestNotEmpty(manifest)
    whenManifestProtocolNotEmpty(manifestProtocol)
  {
    Version storage version = services[sidHash].versions[hash];
    version.manifest = manifest;
    version.manifestProtocol = manifestProtocol;
    version.createTime = now;
    services[sidHash].versionsList.push(hash);
    hashToService[hash] = sidHash;
    emit ServiceVersionCreated(sidHash, hash, manifest, manifestProtocol);
  }

  function createServiceOffer(bytes32 sidHash, uint price, uint duration)
    external
    whenNotPaused
    onlyServiceOwner(sidHash)
    whenServiceVersionNotEmpty(sidHash)
    whenDurationNotZero(duration)
    returns (uint offerIndex)
  {
    Offer[] storage offers = services[sidHash].offers;
    offers.push(Offer({
      createTime: now,
      price: price,
      duration: duration,
      active: true
    }));
    emit ServiceOfferCreated(sidHash, offers.length - 1, price, duration);
    return offers.length - 1;
  }

  function disableServiceOffer(bytes32 sidHash, uint offerIndex)
    external
    whenNotPaused
    onlyServiceOwner(sidHash)
    whenServiceOfferExist(sidHash, offerIndex)
  {
    services[sidHash].offers[offerIndex].active = false;
    emit ServiceOfferDisabled(sidHash, offerIndex);
  }

  function purchase(bytes32 sidHash, uint offerIndex)
    external
    whenNotPaused
    whenServiceExist(sidHash)
    notServiceOwner(sidHash)
    whenServiceOfferExist(sidHash, offerIndex)
    whenServiceOfferActive(sidHash, offerIndex)
  {
    Service storage service = services[sidHash];
    Offer storage offer = service.offers[offerIndex];

    // if offer has been purchased for infinity then return
    require(service.purchases[msg.sender].expire != INFINITY, "Service has been already purchased");

    // Check if offer is active, sender has enough balance and approved the transform
    require(token.balanceOf(msg.sender) >= offer.price, "Sender does not have enough balance to pay this service");
    require(token.allowance(msg.sender, address(this)) >= offer.price, "Sender did not approve this contract to spend on his behalf. Execute approve function on the token contract");

    // Transfer the token from sender to service owner
    token.transferFrom(msg.sender, service.owner, offer.price);

    // max(service.purchases[msg.sender].expire,  now)
    uint expire = service.purchases[msg.sender].expire <= now ?
                    now : service.purchases[msg.sender].expire;

    // set expire + duration or INFINITY on overflow
    expire = expire + offer.duration < expire ?
               INFINITY : expire + offer.duration;

    // if given address purchase service
    // 1st time add it to purchases list and set create time
    if (service.purchases[msg.sender].expire == 0) {
      service.purchases[msg.sender].createTime = now;
      service.purchasesList.push(msg.sender);
    }

    // set new expire time
    service.purchases[msg.sender].expire = expire;
    emit ServicePurchased(sidHash, offerIndex, msg.sender, offer.price, offer.duration, expire);
  }

  /**
    External views
   */

  function servicesListLength()
    external view
    returns (uint length)
  {
    return servicesList.length;
  }

  function servicesVersionsListLength(bytes32 sidHash)
    external view
    whenServiceExist(sidHash)
    returns (uint length)
  {
    return services[sidHash].versionsList.length;
  }

  function servicesVersionsList(bytes32 sidHash, uint versionIndex)
    external view
    whenServiceExist(sidHash)
    returns (bytes32 hash)
  {
    return services[sidHash].versionsList[versionIndex];
  }

  function servicesVersion(bytes32 sidHash, bytes32 hash)
    external view
    whenServiceExist(sidHash)
    returns (uint256 createTime, bytes memory manifest, bytes memory manifestProtocol)
  {
    Version storage version = services[sidHash].versions[hash];
    return (version.createTime, version.manifest, version.manifestProtocol);
  }

  function servicesOffersLength(bytes32 sidHash)
    external view
    whenServiceExist(sidHash)
    returns (uint length)
  {
    return services[sidHash].offers.length;
  }

  function servicesOffer(bytes32 sidHash, uint offerIndex)
    external view
    whenServiceExist(sidHash)
    returns (uint256 createTime, uint price, uint duration, bool active)
  {
    Offer storage offer = services[sidHash].offers[offerIndex];
    return (offer.createTime, offer.price, offer.duration, offer.active);
  }

  function servicesPurchasesListLength(bytes32 sidHash)
    external view
    whenServiceExist(sidHash)
    returns (uint length)
  {
    return services[sidHash].purchasesList.length;
  }

  function servicesPurchasesList(bytes32 sidHash, uint purchaseIndex)
    external view
    whenServiceExist(sidHash)
    returns (address purchaser)
  {
    return services[sidHash].purchasesList[purchaseIndex];
  }

  function servicesPurchase(bytes32 sidHash, address purchaser)
    external view
    whenServiceExist(sidHash)
    returns (uint256 createTime, uint expire)
  {
    Purchase storage p = services[sidHash].purchases[purchaser];
    return (p.createTime, p.expire);
  }

  function isAuthorized(bytes32 sidHash, address purchaser)
    external view
    returns (bool authorized)
  {
    return services[sidHash].owner == purchaser ||
      services[sidHash].purchases[purchaser].expire >= now;
  }

  /**
    Publics
   */

  function isServiceExist(bytes32 sidHash) public view returns (bool exist) {
    return services[sidHash].owner != address(0);
  }

  function isServiceVersionExist(bytes32 sidHash, bytes32 hash) public view returns (bool exist) {
    return services[sidHash].versions[hash].createTime > 0;
  }

  function isServiceOfferExist(bytes32 sidHash, uint offerIndex) public view returns (bool exist) {
    return offerIndex < services[sidHash].offers.length;
  }

  function isServicesPurchaseExist(bytes32 sidHash, address purchaser) public view returns (bool exist) {
    return services[sidHash].purchases[purchaser].createTime > 0;
  }
}
