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
  uint constant SID_MIN_LEN = 1;
  uint constant SID_MAX_LEN = 63;

  /**
    Errors
  */

  string constant private ERR_ADDRESS_ZERO = "address is zero";

  string constant private ERR_SID_LEN = "sid must be between 1 and 63 characters";
  string constant private ERR_SID_INVALID = "sid must be a valid dns name";

  string constant private ERR_SERVICE_EXIST = "service with given sid already exists";
  string constant private ERR_SERVICE_NOT_EXIST = "service with given sid does not exist";
  string constant private ERR_SERVICE_NOT_OWNER = "sender is not the service owner";

  string constant private ERR_VERSION_EXIST = "version with given hash already exists";
  string constant private ERR_VERSION_MANIFEST_LEN = "version manifest must have at least 1 character";
  string constant private ERR_VERSION_MANIFEST_PROTOCOL_LEN = "version manifest protocol must have at least 1 character";

  string constant private ERR_OFFER_NOT_EXIST = "offer dose not exist";
  string constant private ERR_OFFER_NO_VERSION = "offer must be created with at least 1 version";
  string constant private ERR_OFFER_NOT_ACTIVE = "offer must be active";
  string constant private ERR_OFFER_DURATION_MIN = "offer duration must be grather then 0";

  string constant private ERR_PURCHASE_OWNER = "sender cannot purchase his own service";
  string constant private ERR_PURCHASE_INFINITY = "service already purchase for infinity";
  string constant private ERR_PURCHASE_TOKEN_BALANCE = "token balance must be grather to purchase the service";
  string constant private ERR_PURCHASE_TOKEN_APPROVE = "sender must approve the marketplace to spend token";

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
    address indexed owner
  );

  event ServiceOwnershipTransferred(
    bytes sid,
    address indexed previousOwner,
    address indexed newOwner
  );

  event ServiceVersionCreated(
    bytes sid,
    bytes32 indexed hash,
    bytes manifest,
    bytes manifestProtocol
  );

  event ServiceOfferCreated(
    bytes sid,
    uint indexed index,
    uint price,
    uint duration
  );

  event ServiceOfferDisabled(
    bytes sid,
    uint indexed index
  );

  event ServicePurchased(
    bytes sid,
    uint indexed index,
    address indexed purchaser,
    uint price,
    uint duration,
    uint expire
  );

  /**
    Modifiers
   */

  modifier whenAddressNotZero(address a) {
    require(a != address(0), ERR_ADDRESS_ZERO);
    _;
  }

  modifier whenManifestNotEmpty(bytes memory manifest) {
    require(!manifest.isZero(), ERR_VERSION_MANIFEST_LEN);
    _;
  }

  modifier whenManifestProtocolNotEmpty(bytes memory manifestProtocol) {
    require(!manifestProtocol.isZero(), ERR_VERSION_MANIFEST_PROTOCOL_LEN);
    _;
  }

  modifier whenDurationNotZero(uint duration) {
    require(duration > 0, ERR_OFFER_DURATION_MIN);
    _;
  }

  modifier whenServiceHashNotExist(bytes32 versionHash) {
    require(services[hashToService[versionHash]].owner == address(0), ERR_VERSION_EXIST);
    _;
  }


  /**
    Internals
   */

  function _isServiceExist(bytes32 sidHash) internal view returns (bool exist) {
    return services[sidHash].owner != address(0);
  }

  function _isServiceOwner(bytes32 sidHash, address owner) internal view returns (bool isOwner) {
    return services[sidHash].owner == owner;
  }

  function _isServiceVersionExist(bytes32 sidHash, bytes32 versionHash) internal view returns (bool exist) {
    return services[sidHash].versions[versionHash].createTime > 0;
  }

  function _isServiceOfferExist(bytes32 sidHash, uint offerIndex) internal view returns (bool exist) {
    return offerIndex < services[sidHash].offers.length;
  }

  function _isServicesPurchaseExist(bytes32 sidHash, address purchaser) internal view returns (bool exist) {
    return services[sidHash].purchases[purchaser].createTime > 0;
  }

  /**
    Externals
   */

  function createService(bytes calldata sid)
    external
    whenNotPaused
  {
    require(SID_MIN_LEN <= sid.length && sid.length <= SID_MAX_LEN, ERR_SID_LEN);
    require(sid.isDomainName(), ERR_SID_INVALID);
    bytes32 sidHash = keccak256(sid);
    require(services[sidHash].owner == address(0), ERR_SERVICE_EXIST);
    services[sidHash].owner = msg.sender;
    services[sidHash].sid = sid;
    services[sidHash].createTime = now;
    servicesList.push(sidHash);
    emit ServiceCreated(sid, msg.sender);
  }

  function transferServiceOwnership(bytes calldata sid, address newOwner)
    external
    whenNotPaused
    whenAddressNotZero(newOwner)
  {
    bytes32 sidHash = keccak256(sid);
    require(_isServiceOwner(sidHash, msg.sender), ERR_SERVICE_NOT_OWNER);
    emit ServiceOwnershipTransferred(sid, services[sidHash].owner, newOwner);
    services[sidHash].owner = newOwner;
  }

  function createServiceVersion(
    bytes calldata sid,
    bytes32 versionHash,
    bytes calldata manifest,
    bytes calldata manifestProtocol
  )
    external
    whenNotPaused
    whenServiceHashNotExist(versionHash)
    whenManifestNotEmpty(manifest)
    whenManifestProtocolNotEmpty(manifestProtocol)
  {
    bytes32 sidHash = keccak256(sid);
    require(_isServiceOwner(sidHash, msg.sender), ERR_SERVICE_NOT_OWNER);
    Version storage version = services[sidHash].versions[versionHash];
    version.manifest = manifest;
    version.manifestProtocol = manifestProtocol;
    version.createTime = now;
    services[sidHash].versionsList.push(versionHash);
    hashToService[versionHash] = sidHash;
    emit ServiceVersionCreated(sid, versionHash, manifest, manifestProtocol);
  }

  function createServiceOffer(bytes calldata sid, uint price, uint duration)
    external
    whenNotPaused
    whenDurationNotZero(duration)
    returns (uint offerIndex)
  {
    bytes32 sidHash = keccak256(sid);
    require(_isServiceOwner(sidHash, msg.sender), ERR_SERVICE_NOT_OWNER);
    require(services[sidHash].versionsList.length > 0, ERR_OFFER_NO_VERSION);
    Offer[] storage offers = services[sidHash].offers;
    offers.push(Offer({
      createTime: now,
      price: price,
      duration: duration,
      active: true
    }));
    emit ServiceOfferCreated(sid, offers.length - 1, price, duration);
    return offers.length - 1;
  }

  function disableServiceOffer(bytes calldata sid, uint offerIndex)
    external
    whenNotPaused
  {
    bytes32 sidHash = keccak256(sid);
    require(_isServiceOwner(sidHash, msg.sender), ERR_SERVICE_NOT_OWNER);
    require(_isServiceOfferExist(sidHash, offerIndex), ERR_OFFER_NOT_EXIST);
    services[sidHash].offers[offerIndex].active = false;
    emit ServiceOfferDisabled(sid, offerIndex);
  }

  function purchase(bytes calldata sid, uint offerIndex)
    external
    whenNotPaused
  {
    bytes32 sidHash = keccak256(sid);
    require(_isServiceExist(sidHash), ERR_SERVICE_NOT_EXIST);
    require(!_isServiceOwner(sidHash, msg.sender), ERR_PURCHASE_OWNER);
    require(_isServiceOfferExist(sidHash, offerIndex), ERR_OFFER_NOT_EXIST);
    require(services[sidHash].offers[offerIndex].active, ERR_OFFER_NOT_ACTIVE);

    Service storage service = services[sidHash];
    Offer storage offer = service.offers[offerIndex];

    // if offer has been purchased for infinity then return
    require(service.purchases[msg.sender].expire != INFINITY, ERR_PURCHASE_INFINITY);

    // Check if offer is active, sender has enough balance and approved the transform
    require(token.balanceOf(msg.sender) >= offer.price, ERR_PURCHASE_TOKEN_BALANCE);
    require(token.allowance(msg.sender, address(this)) >= offer.price, ERR_PURCHASE_TOKEN_APPROVE);

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
    emit ServicePurchased(sid, offerIndex, msg.sender, offer.price, offer.duration, expire);
  }

  /**
    External views
   */
  function servicesLength()
    external view
    returns (uint length)
  {
    return servicesList.length;
  }

  function service(bytes calldata _sid)
    external view
    returns (uint256 createTime, address owner, bytes memory sid)
  {
    bytes32 sidHash = keccak256(_sid);
    Service storage s = services[sidHash];
    return (s.createTime, s.owner, s.sid);
  }

  function serviceVersionsLength(bytes calldata sid)
    external view
    returns (uint length)
  {
    bytes32 sidHash = keccak256(sid);
    require(_isServiceExist(sidHash), ERR_SERVICE_NOT_EXIST);
    return services[sidHash].versionsList.length;
  }

  function serviceVersionHash(bytes calldata sid, uint versionIndex)
    external view
    returns (bytes32 versionHash)
  {
    bytes32 sidHash = keccak256(sid);
    require(_isServiceExist(sidHash), ERR_SERVICE_NOT_EXIST);
    return services[sidHash].versionsList[versionIndex];
  }

  function serviceVersion(bytes calldata sid, bytes32 versionHash)
    external view
    returns (uint256 createTime, bytes memory manifest, bytes memory manifestProtocol)
  {
    bytes32 sidHash = keccak256(sid);
    require(_isServiceExist(sidHash), ERR_SERVICE_NOT_EXIST);
    Version storage version = services[sidHash].versions[versionHash];
    return (version.createTime, version.manifest, version.manifestProtocol);
  }

  function serviceOffersLength(bytes calldata sid)
    external view
    returns (uint length)
  {
    bytes32 sidHash = keccak256(sid);
    require(_isServiceExist(sidHash), ERR_SERVICE_NOT_EXIST);
    return services[sidHash].offers.length;
  }

  function serviceOffer(bytes calldata sid, uint offerIndex)
    external view
    returns (uint256 createTime, uint price, uint duration, bool active)
  {
    bytes32 sidHash = keccak256(sid);
    require(_isServiceExist(sidHash), ERR_SERVICE_NOT_EXIST);
    Offer storage offer = services[sidHash].offers[offerIndex];
    return (offer.createTime, offer.price, offer.duration, offer.active);
  }

  function servicePurchasesLength(bytes calldata sid)
    external view
    returns (uint length)
  {
    bytes32 sidHash = keccak256(sid);
    require(_isServiceExist(sidHash), ERR_SERVICE_NOT_EXIST);
    return services[sidHash].purchasesList.length;
  }

  function servicePurchaseAddress(bytes calldata sid, uint purchaseIndex)
    external view
    returns (address purchaser)
  {
    bytes32 sidHash = keccak256(sid);
    require(_isServiceExist(sidHash), ERR_SERVICE_NOT_EXIST);
    return services[sidHash].purchasesList[purchaseIndex];
  }

  function servicePurchase(bytes calldata sid, address purchaser)
    external view
    returns (uint256 createTime, uint expire)
  {
    bytes32 sidHash = keccak256(sid);
    require(_isServiceExist(sidHash), ERR_SERVICE_NOT_EXIST);
    Purchase storage p = services[sidHash].purchases[purchaser];
    return (p.createTime, p.expire);
  }

  function isAuthorized(bytes calldata sid, address purchaser)
    external view
    returns (bool authorized)
  {
    bytes32 sidHash = keccak256(sid);
    return services[sidHash].owner == purchaser ||
      services[sidHash].purchases[purchaser].expire >= now;
  }

  /**
    Publics
   */

  function isServiceExist(bytes memory sid) public view returns (bool exist) {
    bytes32 sidHash = keccak256(sid);
    return _isServiceExist(sidHash);
  }

  function isServiceOwner(bytes memory sid, address owner) public view returns (bool isOwner) {
    bytes32 sidHash = keccak256(sid);
    return _isServiceOwner(sidHash, owner);
  }

  function isServiceVersionExist(bytes memory sid, bytes32 versionHash) public view returns (bool exist) {
    bytes32 sidHash = keccak256(sid);
    return _isServiceVersionExist(sidHash, versionHash);
  }

  function isServiceOfferExist(bytes memory sid, uint offerIndex) public view returns (bool exist) {
    bytes32 sidHash = keccak256(sid);
    return _isServiceOfferExist(sidHash, offerIndex);
  }

  function isServicesPurchaseExist(bytes memory sid, address purchaser) public view returns (bool exist) {
    bytes32 sidHash = keccak256(sid);
    return _isServicesPurchaseExist(sidHash, purchaser);
  }

}
