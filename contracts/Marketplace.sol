pragma solidity >=0.5.0 <0.6.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

contract Marketplace is Ownable, Pausable {
  // ------------------------------------------------------
  // Structures
  // ------------------------------------------------------

  struct Service {
    address owner;
    bytes32 sid;

    Version[] versions;
    Purchase[] purchases;
    Offer[] offers;
  }

  struct Version {
    bytes20 hash;
    bytes metadata;
  }

  struct Purchase {
    address purchaser;
    uint expirationDate;
  }

  struct Offer {
    uint price;
    uint duration;
    bool active;
  }

  struct VersionIndexes {
    uint serviceIndex;
    uint versionIndex;
  }

  // ------------------------------------------------------
  // State variables
  // ------------------------------------------------------

  Service[] public services;
  mapping(bytes32 => uint) private sidToService;
  mapping(bytes20 => VersionIndexes) private hashToVersion;
  mapping(address => mapping(bytes32 => uint)) private purchaserToSidToPurchase;

  IERC20 public token;

  // ------------------------------------------------------
  // Constructor
  // ------------------------------------------------------

  constructor(IERC20 _token) public {
    token = _token;
  }

  // ------------------------------------------------------
  // Events
  // ------------------------------------------------------

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
    uint indexed versionIndex,
    bytes20 hash,
    bytes metadata
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
    uint expirationDate
  );

  // ------------------------------------------------------
  // Modifier functions
  // ------------------------------------------------------

  // Throw if service not found
  // Throw if service owner is not the sender
  modifier onlyServiceOwner(bytes32 sid) {
    require(isServiceOwner(sid), "Service owner is not the same as the sender");
    _;
  }

  // ------------------------------------------------------
  // View functions
  // ------------------------------------------------------

  // Index

  // Throw if service not found
  function getServiceIndex(bytes32 sid) public view returns (uint serviceIndex) {
    require(isServiceSidExist(sid), "Service not found");
    return sidToService[sid];
  }

  // Throw if version not found
  function getServiceVersionIndexes(bytes20 hash) public view returns (uint serviceIndex, uint versionIndex) {
    require(isServiceHashExist(hash), "Version not found");
    return (hashToVersion[hash].serviceIndex, hashToVersion[hash].versionIndex);
  }

  // Throw if service not found
  // Throw if purchase not found
  function getServicePurchaseIndexes(bytes32 sid, address purchaser) public view returns (uint serviceIndex, uint purchaseIndex) {
    uint _serviceIndex = getServiceIndex(sid);
    require(isServicePurchaseExist(sid, purchaser), "Purchase not found");
    uint _purchaserIndex = purchaserToSidToPurchase[purchaser][sid];
    return (_serviceIndex, _purchaserIndex);
  }

  // Check function

  // Throw if service not found
  function isServiceOwner(bytes32 sid) public view returns (bool) {
    uint _serviceIndex = getServiceIndex(sid);
    return services[_serviceIndex].owner == msg.sender;
  }

  function isServiceSidExist(bytes32 sid) public view returns (bool) {
    uint _serviceIndex = sidToService[sid];
    if (_serviceIndex >= services.length) {
      return false;
    }
    return services[_serviceIndex].sid == sid;
  }

  function isServiceHashExist(bytes20 hash) public view returns (bool) {
    VersionIndexes storage _indexes = hashToVersion[hash];
    if (_indexes.serviceIndex >= services.length) {
      return false;
    }
    Service storage _service = services[_indexes.serviceIndex];
    if (_indexes.versionIndex >= _service.versions.length) {
      return false;
    }
    return _service.versions[_indexes.versionIndex].hash == hash;
  }

  // Throw if service not found
  function isServicePurchaseExist(bytes32 sid, address purchaser) public view returns (bool) {
    uint _serviceIndex = getServiceIndex(sid);
    Service storage _service = services[_serviceIndex];
    uint _purchaseIndex = purchaserToSidToPurchase[purchaser][sid];
    if (_purchaseIndex >= _service.purchases.length) {
      return false;
    }
    return _service.purchases[_purchaseIndex].purchaser == purchaser;
  }

  // Throw if service not found
  function isServiceOfferExist(bytes32 sid, uint offerIndex) public view returns (bool) {
    uint _serviceIndex = getServiceIndex(sid);
    return offerIndex < services[_serviceIndex].offers.length;
  }

  // Getters

  // Throw if service not found
  function getService(bytes32 _sid) external view returns (address owner, bytes32 sid) {
    uint _serviceIndex = getServiceIndex(_sid);
    Service storage _service = services[_serviceIndex];
    return (_service.owner, _service.sid);
  }

  // Throw if version not found
  function getServiceVersion(bytes20 _hash) external view returns (bytes20 hash, bytes memory metadata) {
    (uint _serviceIndex, uint _versionIndex) = getServiceVersionIndexes(_hash);
    Version storage _version = services[_serviceIndex].versions[_versionIndex];
    return (_version.hash, _version.metadata);
  }

  // Throw if service not found
  // Throw if version not found
  function getServiceVersionWithIndex(bytes32 sid, uint versionIndex) external view returns (bytes20 hash, bytes memory metadata) {
    uint _serviceIndex = getServiceIndex(sid);
    require(versionIndex < services[_serviceIndex].versions.length, "Version not found");
    Version storage _version = services[_serviceIndex].versions[versionIndex];
    return (_version.hash, _version.metadata);
  }

  // Throw if service not found
  // Throw if purchase not found
  function getServicePurchase(bytes32 sid, address _purchaser) public view returns (address purchaser, uint expirationDate) {
    (uint _serviceIndex, uint _purchaseIndex) = getServicePurchaseIndexes(sid, _purchaser);
    Purchase storage _purchase = services[_serviceIndex].purchases[_purchaseIndex];
    return (_purchase.purchaser, _purchase.expirationDate);
  }

  // Throw if service not found
  // Throw if purchase not found
  function getServicePurchaseWithIndex(bytes32 sid, uint purchaseIndex) external view returns (address purchaser, uint expirationDate) {
    uint _serviceIndex = getServiceIndex(sid);
    require(purchaseIndex < services[_serviceIndex].purchases.length, "Purchase not found");
    Purchase storage _purchase = services[_serviceIndex].purchases[purchaseIndex];
    return (_purchase.purchaser, _purchase.expirationDate);
  }

  // Throw if service not found
  // Throw if offer not found
  function getServiceOfferWithIndex(bytes32 sid, uint offerIndex) external view returns (uint price, uint duration, bool active) {
    uint _serviceIndex = getServiceIndex(sid);
    require(isServiceOfferExist(sid, offerIndex), "Offer not found");
    Offer storage _offer = services[_serviceIndex].offers[offerIndex];
    return (_offer.price, _offer.duration, _offer.active);
  }

  // Count

  function getServicesCount() external view returns (uint) {
    return services.length;
  }

  // Throw if service not found
  function getServiceVersionsCount(bytes32 sid) external view returns (uint) {
    uint _serviceIndex = getServiceIndex(sid);
    return services[_serviceIndex].versions.length;
  }

  // Throw if service not found
  function getServicePurchasesCount(bytes32 sid) external view returns (uint) {
    uint _serviceIndex = getServiceIndex(sid);
    return services[_serviceIndex].purchases.length;
  }

  // Throw if service not found
  function getServiceOffersCount(bytes32 sid) external view returns (uint) {
    uint _serviceIndex = getServiceIndex(sid);
    return services[_serviceIndex].offers.length;
  }

  // ------------------------------------------------------
  // Setter functions
  // ------------------------------------------------------

  // Manage Service

  // Throw if sid already exist
  function createService (bytes32 sid) external whenNotPaused returns (uint serviceIndex) {
    require(!isServiceSidExist(sid), "Service's sid is already used");
    services.length++;
    Service storage _service = services[services.length - 1];
    _service.sid = sid;
    _service.owner = msg.sender;
    sidToService[sid] = services.length - 1;
    emit ServiceCreated(
      sid,
      _service.owner
    );
    return services.length - 1;
  }

  // Throw if service not found
  // Throw if service owner is not the sender
  // Throw if new owner address is 0
  // Throw if new owner is current owner
  function transferServiceOwnership (bytes32 sid, address newOwner) external whenNotPaused onlyServiceOwner(sid) {
    require(newOwner != address(0), "New Owner cannot be address 0");
    uint _serviceIndex = getServiceIndex(sid);
    Service storage _service = services[_serviceIndex];
    require(newOwner != _service.owner, "New Owner is already current owner");
    emit ServiceOwnershipTransferred(
      sid,
      _service.owner,
      newOwner
    );
    _service.owner = newOwner;
  }

  // Manage Version

  // Throw if service not found
  // Throw if service owner is not the sender
  // Throw if hash already exist
  function createServiceVersion (bytes32 sid, bytes20 hash, bytes calldata metadata)
    external
    whenNotPaused
    onlyServiceOwner(sid)
  returns (uint versionIndex) {
    uint _serviceIndex = getServiceIndex(sid);
    require(!isServiceHashExist(hash), "Version's hash already exists");
    services[_serviceIndex].versions.push(Version({
      hash: hash,
      metadata: metadata
    }));
    uint _versionIndex = services[_serviceIndex].versions.length - 1;
    hashToVersion[hash] = VersionIndexes(
      _serviceIndex,
      _versionIndex
    );
    emit ServiceVersionCreated(
      sid,
      _versionIndex,
      hash,
      metadata
    );
    return _versionIndex;
  }

  // Manage Offer

  // Throw if service not found
  // Throw if service owner is not the sender
  function createServiceOffer (bytes32 sid, uint price, uint duration)
    external
    whenNotPaused
    onlyServiceOwner(sid)
  returns (uint offerIndex) {
    uint _serviceIndex = getServiceIndex(sid);
    Service storage _service = services[_serviceIndex];
    require(_service.versions.length > 0, "Cannot create an offer on a service without version");
    _service.offers.push(Offer({
      price: price,
      duration: duration,
      active: true
    }));
    uint _offerIndex = _service.offers.length - 1;
    emit ServiceOfferCreated(
      sid,
      _offerIndex,
      price,
      duration
    );
    return _offerIndex;
  }

  // Throw if service not found
  // Throw if service owner is not the sender
  // Throw if offer not found
  function disableServiceOffer (bytes32 sid, uint offerIndex)
    external
    whenNotPaused
    onlyServiceOwner(sid)
  returns (uint _offerIndex) {
    uint _serviceIndex = getServiceIndex(sid);
    require(isServiceOfferExist(sid, offerIndex), "Offer not found");
    services[_serviceIndex].offers[offerIndex].active = false;
    emit ServiceOfferDisabled(
      sid,
      offerIndex
    );
    return offerIndex;
  }

  // ------------------------------------------------------
  // Purchase
  // ------------------------------------------------------

  // Throw if service not found
  function hasPurchased(bytes32 sid) public view returns (bool purchased) {
    if (!isServicePurchaseExist(sid, msg.sender)) {
      return false;
    }
    (, uint _expirationDate) = getServicePurchase(sid, msg.sender);
    return _expirationDate >= now;
  }

  // Throw if service not found
  // Throw if offer not found
  // Throw if offer is disable
  // Throw if sender doesn't have enough balance
  // Throw if sender didn't approve the contract on the ERC20
  function purchase(bytes32 sid, uint offerIndex) external whenNotPaused returns (uint purchaseIndex) {
    uint _serviceIndex = getServiceIndex(sid);
    require(isServiceOfferExist(sid, offerIndex), "Offer not found");
    Service storage _service = services[_serviceIndex];
    Offer storage _offer = _service.offers[offerIndex];

    // Check if offer is active, sender has enough balance and approved the transform
    require(_offer.active, "Cannot purchase a disabled offer");
    require(token.balanceOf(msg.sender) >= _offer.price, "Sender doesn't have enough balance to pay this service");
    require(
      token.allowance(msg.sender, address(this)) >= _offer.price,
      "Sender didn't approve this contract to spend on his behalf. Execute approve function on the token contract"
    );

    // Transfer the token from sender to service owner
    token.transferFrom(msg.sender, _service.owner, _offer.price);

    // Calculate expiration date
    uint _expirationDate = now;
    uint _purchaseIndex;
    if (isServicePurchaseExist(sid, msg.sender)) {
      // If already purchased, update expiration
      (, _purchaseIndex) = getServicePurchaseIndexes(sid, msg.sender);
      Purchase storage _purchase = _service.purchases[_purchaseIndex];
      // If current expiration date is later than now, use it
      if (_purchase.expirationDate > _expirationDate) {
        _expirationDate = _purchase.expirationDate;
      }
      _expirationDate = _expirationDate + _offer.duration;
      _purchase.expirationDate = _expirationDate;
    }
    else {
      // Create new purchase
      _expirationDate = _expirationDate + _offer.duration;
      _service.purchases.push(Purchase({
        purchaser: msg.sender,
        expirationDate: _expirationDate
      }));
      _purchaseIndex = _service.purchases.length - 1;
      purchaserToSidToPurchase[msg.sender][sid] = _purchaseIndex;
    }

    // Emit event
    emit ServicePurchased(
      sid,
      offerIndex,
      msg.sender,
      _offer.price,
      _offer.duration,
      _expirationDate
    );
    return _purchaseIndex;
  }
}
