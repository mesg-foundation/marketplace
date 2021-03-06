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

    mapping(bytes32 => Version) versions; // version hash => Version
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
  string constant private ERR_OFFER_DURATION_MIN = "offer duration must be greater than 0";

  string constant private ERR_PURCHASE_OWNER = "sender cannot purchase his own service";
  string constant private ERR_PURCHASE_INFINITY = "service already purchase for infinity";
  string constant private ERR_PURCHASE_TOKEN_BALANCE = "token balance must be greater to purchase the service";
  string constant private ERR_PURCHASE_TOKEN_APPROVE = "sender must approve the marketplace to spend token";

  /**
    State variables
   */

  IERC20 public token;

  mapping(bytes32 => Service) public services; // service hashed sid => Service
  bytes32[] public servicesList;

  mapping(bytes32 => bytes32) public versionHashToService; // version hash => service hashed sid

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
    bytes32 indexed versionHash,
    bytes manifest,
    bytes manifestProtocol
  );

  event ServiceOfferCreated(
    bytes sid,
    uint indexed offerIndex,
    uint price,
    uint duration
  );

  event ServiceOfferDisabled(
    bytes sid,
    uint indexed offerIndex
  );

  event ServicePurchased(
    bytes sid,
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

  /**
    Internals
   */

  function _service(bytes memory sid)
    internal view
    returns (Service storage service, bytes32 sidHash)
  {
    sidHash = keccak256(sid);
    require(_isServiceExist(sidHash), ERR_SERVICE_NOT_EXIST);
    return (services[sidHash], sidHash);
  }

  function _isServiceExist(bytes32 sidHash)
    internal view
    returns (bool exist)
  {
    return services[sidHash].owner != address(0);
  }

  function _isServiceOwner(bytes32 sidHash, address owner)
    internal view
    returns (bool isOwner)
  {
    return services[sidHash].owner == owner;
  }

  function _isServiceOfferExist(bytes32 sidHash, uint offerIndex)
    internal view
    returns (bool exist)
  {
    return offerIndex < services[sidHash].offers.length;
  }

  function _isServicesPurchaseExist(bytes32 sidHash, address purchaser)
    internal view
    returns (bool exist)
  {
    return services[sidHash].purchases[purchaser].createTime > 0;
  }

  /**
    External and public functions
   */

  function createService(bytes memory sid)
    public
    whenNotPaused
  {
    require(SID_MIN_LEN <= sid.length && sid.length <= SID_MAX_LEN, ERR_SID_LEN);
    require(sid.isDomainName(), ERR_SID_INVALID);
    bytes32 sidHash = keccak256(sid);
    require(!_isServiceExist(sidHash), ERR_SERVICE_EXIST);
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
    (Service storage service, bytes32 sidHash) = _service(sid);
    require(_isServiceOwner(sidHash, msg.sender), ERR_SERVICE_NOT_OWNER);
    emit ServiceOwnershipTransferred(sid, service.owner, newOwner);
    service.owner = newOwner;
  }

  function createServiceVersion(
    bytes memory sid,
    bytes memory manifest,
    bytes memory manifestProtocol
  )
    public
    whenNotPaused
    whenManifestNotEmpty(manifest)
    whenManifestProtocolNotEmpty(manifestProtocol)
  {
    (Service storage service, bytes32 sidHash) = _service(sid);
    require(_isServiceOwner(sidHash, msg.sender), ERR_SERVICE_NOT_OWNER);
    bytes32 versionHash = keccak256(abi.encodePacked(msg.sender, sid, manifest, manifestProtocol));
    require(!isServiceVersionExist(versionHash), ERR_VERSION_EXIST);
    Version storage version = service.versions[versionHash];
    version.manifest = manifest;
    version.manifestProtocol = manifestProtocol;
    version.createTime = now;
    services[sidHash].versionsList.push(versionHash);
    versionHashToService[versionHash] = sidHash;
    emit ServiceVersionCreated(sid, versionHash, manifest, manifestProtocol);
  }

  function publishServiceVersion(
    bytes calldata sid,
    bytes calldata manifest,
    bytes calldata manifestProtocol
  )
    external
    whenNotPaused
  {
    if (!isServiceExist(sid)) {
      createService(sid);
    }
    createServiceVersion(sid, manifest, manifestProtocol);
  }

  function createServiceOffer(bytes calldata sid, uint price, uint duration)
    external
    whenNotPaused
    whenDurationNotZero(duration)
    returns (uint offerIndex)
  {
    (Service storage service, bytes32 sidHash) = _service(sid);
    require(_isServiceOwner(sidHash, msg.sender), ERR_SERVICE_NOT_OWNER);
    require(service.versionsList.length > 0, ERR_OFFER_NO_VERSION);
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
    (Service storage service, bytes32 sidHash) = _service(sid);
    require(_isServiceOwner(sidHash, msg.sender), ERR_SERVICE_NOT_OWNER);
    require(_isServiceOfferExist(sidHash, offerIndex), ERR_OFFER_NOT_EXIST);
    service.offers[offerIndex].active = false;
    emit ServiceOfferDisabled(sid, offerIndex);
  }

  function purchase(bytes calldata sid, uint offerIndex)
    external
    whenNotPaused
  {
    (Service storage service, bytes32 sidHash) = _service(sid);
    require(!_isServiceOwner(sidHash, msg.sender), ERR_PURCHASE_OWNER);
    require(_isServiceOfferExist(sidHash, offerIndex), ERR_OFFER_NOT_EXIST);
    require(service.offers[offerIndex].active, ERR_OFFER_NOT_ACTIVE);

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
    emit ServicePurchased(
      sid,
      offerIndex,
      msg.sender,
      offer.price,
      offer.duration,
      expire
    );
  }

  function destroy() public onlyOwner {
    selfdestruct(msg.sender);
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
    (Service storage s,) = _service(sid);
    return s.versionsList.length;
  }

  function serviceVersionHash(bytes calldata sid, uint versionIndex)
    external view
    returns (bytes32 versionHash)
  {
    (Service storage s,) = _service(sid);
    return s.versionsList[versionIndex];
  }

  function serviceVersion(bytes32 versionHash)
    external view
    returns (
      uint256 createTime,
      bytes memory manifest,
      bytes memory manifestProtocol
    )
  {
    bytes32 sidHash = versionHashToService[versionHash];
    require(_isServiceExist(sidHash), ERR_SERVICE_NOT_EXIST);
    Version storage version = services[sidHash].versions[versionHash];
    return (version.createTime, version.manifest, version.manifestProtocol);
  }

  function serviceOffersLength(bytes calldata sid)
    external view
    returns (uint length)
  {
    (Service storage s,) = _service(sid);
    return s.offers.length;
  }

  function serviceOffer(bytes calldata sid, uint offerIndex)
    external view
    returns (uint256 createTime, uint price, uint duration, bool active)
  {
    (Service storage s,) = _service(sid);
    Offer storage offer = s.offers[offerIndex];
    return (offer.createTime, offer.price, offer.duration, offer.active);
  }

  function servicePurchasesLength(bytes calldata sid)
    external view
    returns (uint length)
  {
    (Service storage s,) = _service(sid);
    return s.purchasesList.length;
  }

  function servicePurchaseAddress(bytes calldata sid, uint purchaseIndex)
    external view
    returns (address purchaser)
  {
    (Service storage s,) = _service(sid);
    return s.purchasesList[purchaseIndex];
  }

  function servicePurchase(bytes calldata sid, address purchaser)
    external view
    returns (uint256 createTime, uint expire)
  {
    (Service storage s,) = _service(sid);
    Purchase storage p = s.purchases[purchaser];
    return (p.createTime, p.expire);
  }

  function isAuthorized(bytes calldata sid, address purchaser)
    external view
    returns (bool authorized)
  {
    (Service storage s,) = _service(sid);
    if (s.owner == purchaser || s.purchases[purchaser].expire >= now) {
      return true;
    }

    for (uint i = 0; i < s.offers.length; i++) {
      if (s.offers[i].active && s.offers[i].price == 0) {
        return true;
      }
    }

    return false;
  }

  /**
    Public views
   */

  function isServiceExist(bytes memory sid)
    public view
    returns (bool exist)
  {
    bytes32 sidHash = keccak256(sid);
    return _isServiceExist(sidHash);
  }

  function isServiceOwner(bytes memory sid, address owner)
    public view
    returns (bool isOwner)
  {
    bytes32 sidHash = keccak256(sid);
    return _isServiceOwner(sidHash, owner);
  }

  function isServiceVersionExist(bytes32 versionHash)
    public view
    returns (bool exist)
  {
    return _isServiceExist(versionHashToService[versionHash]);
  }

  function isServiceOfferExist(bytes memory sid, uint offerIndex)
    public view
    returns (bool exist)
  {
    bytes32 sidHash = keccak256(sid);
    return _isServiceOfferExist(sidHash, offerIndex);
  }

  function isServicesPurchaseExist(bytes memory sid, address purchaser)
    public view
  returns (bool exist) {
    bytes32 sidHash = keccak256(sid);
    return _isServicesPurchaseExist(sidHash, purchaser);
  }

}
