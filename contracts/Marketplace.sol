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
    address owner;

    mapping(bytes32 => Version) versions; // version's hash => Version
    bytes32[] versionsList;

    Offer[] offers;

    mapping(address => Purchase) purchases; // purchaser's address => Purchase
    address[] purchasesList;
  }

  struct Purchase {
    uint expire;
  }

  struct Version {
    bytes manifest;
    bytes manifestProtocol;
  }

  struct Offer {
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

  mapping(bytes32 => Service) public services; // service's sid => Service
  bytes32[] public servicesList;

  mapping(bytes32 => bytes32) public hashToService; // version's hash => service's sid

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
    bytes32 indexed sid,
    address indexed owner
  );

  event ServiceOwnershipTransferred(
    bytes32 indexed sid,
    address indexed previousOwner,
    address indexed newOwner
  );

  event ServiceVersionCreated(
    bytes32 indexed sid,
    bytes32 indexed hash,
    bytes manifest,
    bytes manifestProtocol
  );

  event ServiceOfferCreated(
    bytes32 indexed sid,
    uint indexed offerIndex,
    uint price,
    uint duration
  );

  event ServiceOfferDisabled(
    bytes32 indexed sid,
    uint indexed offerIndex
  );

  event ServicePurchased(
    bytes32 indexed sid,
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
    require(services[sid].owner != address(0), "Service with this sid does not exist");
    _;
  }

  modifier onlyServiceOwner(bytes32 sid) {
    require(services[sid].owner == msg.sender, "Service owner is not the sender");
    _;
  }

  modifier notServiceOwner(bytes32 sid) {
    require(services[sid].owner != msg.sender, "Service owner cannot be the sender");
    _;
  }

  modifier whenServiceHashNotExist(bytes32 hash) {
    require(services[hashToService[hash]].owner == address(0), "Hash already exists");
    _;
  }

  modifier whenServiceVersionNotEmpty(bytes32 sid) {
    require(services[sid].versionsList.length > 0, "Cannot create an offer on a service without version");
    _;
  }

  modifier whenServiceOfferExist(bytes32 sid, uint offerIndex) {
    require(offerIndex < services[sid].offers.length, "Service offer does not exist");
    _;
  }

  modifier whenServiceOfferActive(bytes32 sid, uint offerIndex) {
    require(services[sid].offers[offerIndex].active, "Service offer is not active");
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
    bytes32 id = keccak256(sid);
    require(services[id].owner == address(0), "Service with same sid already exists");
    services[id].owner = msg.sender;
    servicesList.push(id);
    emit ServiceCreated(id, msg.sender);
  }

  function transferServiceOwnership(bytes32 sid, address newOwner)
    external
    whenNotPaused
    onlyServiceOwner(sid)
    whenAddressNotZero(newOwner)
  {
    emit ServiceOwnershipTransferred(sid, services[sid].owner, newOwner);
    services[sid].owner = newOwner;
  }

  function createServiceVersion(
    bytes32 sid,
    bytes32 hash,
    bytes calldata manifest,
    bytes calldata manifestProtocol
  )
    external
    whenNotPaused
    onlyServiceOwner(sid)
    whenServiceHashNotExist(hash)
    whenManifestNotEmpty(manifest)
    whenManifestProtocolNotEmpty(manifestProtocol)
  {
    services[sid].versions[hash].manifest = manifest;
    services[sid].versions[hash].manifestProtocol = manifestProtocol;
    services[sid].versionsList.push(hash);
    hashToService[hash] = sid;
    emit ServiceVersionCreated(sid, hash, manifest, manifestProtocol);
  }

  function createServiceOffer(bytes32 sid, uint price, uint duration)
    external
    whenNotPaused
    onlyServiceOwner(sid)
    whenServiceVersionNotEmpty(sid)
    whenDurationNotZero(duration)
    returns (uint offerIndex)
  {
    Offer[] storage offers = services[sid].offers;
    offers.push(Offer({
      price: price,
      duration: duration,
      active: true
    }));
    emit ServiceOfferCreated(sid, offers.length - 1, price, duration);
    return offers.length - 1;
  }

  function disableServiceOffer(bytes32 sid, uint offerIndex)
    external
    whenNotPaused
    onlyServiceOwner(sid)
    whenServiceOfferExist(sid, offerIndex)
  {
    services[sid].offers[offerIndex].active = false;
    emit ServiceOfferDisabled(sid, offerIndex);
  }

  function purchase(bytes32 sid, uint offerIndex)
    external
    whenNotPaused
    whenServiceExist(sid)
    notServiceOwner(sid)
    whenServiceOfferExist(sid, offerIndex)
    whenServiceOfferActive(sid, offerIndex)
  {
    Service storage service = services[sid];
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
    // 1st time add it to purchases list
    if (service.purchases[msg.sender].expire == 0) {
      service.purchasesList.push(msg.sender);
    }

    // set new expire time
    service.purchases[msg.sender].expire = expire;
    emit ServicePurchased(sid, offerIndex, msg.sender, offer.price, offer.duration, expire);
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

  function servicesVersionsListLength(bytes32 sid)
    external view
    whenServiceExist(sid)
    returns (uint length)
  {
    return services[sid].versionsList.length;
  }

  function servicesVersionsList(bytes32 sid, uint versionIndex)
    external view
    whenServiceExist(sid)
    returns (bytes32 hash)
  {
    return services[sid].versionsList[versionIndex];
  }

  function servicesVersion(bytes32 sid, bytes32 hash)
    external view
    whenServiceExist(sid)
    returns (bytes memory manifest, bytes memory manifestProtocol)
  {
    Version storage version = services[sid].versions[hash];
    return (version.manifest, version.manifestProtocol);
  }

  function servicesOffersLength(bytes32 sid)
    external view
    whenServiceExist(sid)
    returns (uint length)
  {
    return services[sid].offers.length;
  }

  function servicesOffer(bytes32 sid, uint offerIndex)
    external view
    whenServiceExist(sid)
    returns (uint price, uint duration, bool active)
  {
    Offer storage offer = services[sid].offers[offerIndex];
    return (offer.price, offer.duration, offer.active);
  }

  function servicesPurchasesListLength(bytes32 sid)
    external view
    whenServiceExist(sid)
    returns (uint length)
  {
    return services[sid].purchasesList.length;
  }

  function servicesPurchasesList(bytes32 sid, uint purchaseIndex)
    external view
    whenServiceExist(sid)
    returns (address purchaser)
  {
    return services[sid].purchasesList[purchaseIndex];
  }

  function servicesPurchase(bytes32 sid, address purchaser)
    external view
    whenServiceExist(sid)
    returns (uint expire)
  {
    return services[sid].purchases[purchaser].expire;
  }

  function isAuthorized(bytes32 sid, address purchaser)
    public view
    returns (bool authorized)
  {
    return services[sid].owner == purchaser ||
      services[sid].purchases[purchaser].expire >= now;
  }

  function isAuthorized(bytes32 sid)
    external view
    returns (bool authorized)
  {
    return isAuthorized(sid, msg.sender);
  }
}
