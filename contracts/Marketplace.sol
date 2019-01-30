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
    uint serviceIndex = getServiceIndex(sid);
    return services[serviceIndex].owner == msg.sender;
  }

  function isServiceSidExist(bytes32 sid) public view returns (bool) {
    uint serviceIndex = sidToService[sid];
    if (serviceIndex >= services.length) {
      return false;
    }
    return services[serviceIndex].sid == sid;
  }

  function isServiceHashExist(bytes20 hash) public view returns (bool) {
    VersionIndexes storage indexes = hashToVersion[hash];
    if (indexes.serviceIndex >= services.length) {
      return false;
    }
    Service storage service = services[indexes.serviceIndex];
    if (indexes.versionIndex >= service.versions.length) {
      return false;
    }
    Version storage version = service.versions[indexes.versionIndex];
    return version.hash == hash;
  }

  // Throw if service not found
  function isServicePurchaseExist(bytes32 sid, address purchaser) public view returns (bool) {
    uint _serviceIndex = getServiceIndex(sid);
    Service storage service = services[_serviceIndex];
    uint _purchaseIndex = purchaserToSidToPurchase[purchaser][sid];
    if (_purchaseIndex >= service.purchases.length) {
      return false;
    }
    Purchase storage purchase = service.purchases[_purchaseIndex];
    return purchase.purchaser == purchaser;
  }

  // Getters

  // Throw if version not found
  function getServiceVersion(bytes20 _hash) external view returns (bytes20 hash, bytes memory metadata) {
    (uint serviceIndex, uint versionIndex) = getServiceVersionIndexes(_hash);
    Version storage version = services[serviceIndex].versions[versionIndex];
    return (version.hash, version.metadata);
  }

  // Throw if service not found
  // Throw if version doesn't exist
  function getServiceVersionWithIndex(bytes32 sid, uint versionIndex) external view returns (bytes20 hash, bytes memory metadata) {
    uint serviceIndex = getServiceIndex(sid);
    require(versionIndex < services[serviceIndex].versions.length, "Version index is out of bounds");
    Version storage version = services[serviceIndex].versions[versionIndex];
    return (version.hash, version.metadata);
  }

  // Throw if service not found
  // Throw if purchase not found
  function getServicePurchase(bytes32 sid, address _purchaser) public view returns (address purchaser, uint expirationDate) {
    (uint serviceIndex, uint purchaseIndex) = getServicePurchaseIndexes(sid, _purchaser);
    Purchase storage purchase = services[serviceIndex].purchases[purchaseIndex];
    return (purchase.purchaser, purchase.expirationDate);
  }

  // Throw if service not found
  // Throw if purchase doesn't exist
  function getServicePurchaseWithIndex(bytes32 sid, uint purchaseIndex) external view returns (address purchaser, uint expirationDate) {
    uint serviceIndex = getServiceIndex(sid);
    require(purchaseIndex < services[serviceIndex].purchases.length, "Purchase index is out of bounds");
    Purchase storage purchase = services[serviceIndex].purchases[purchaseIndex];
    return (purchase.purchaser, purchase.expirationDate);
  }

  // Throw if service not found
  // Throw if offer doesn't exist
  function getServiceOfferWithIndex(bytes32 sid, uint offerIndex) external view returns (uint price, uint duration, bool active) {
    uint serviceIndex = getServiceIndex(sid);
    require(offerIndex < services[serviceIndex].offers.length, "Offer index is out of bounds");
    Offer storage offer = services[serviceIndex].offers[offerIndex];
    return (offer.price, offer.duration, offer.active);
  }

  // Count

  function getServicesCount() external view returns (uint) {
    return services.length;
  }

  // Throw if service not found
  function getServiceVersionsCount(bytes32 sid) external view returns (uint) {
    uint serviceIndex = getServiceIndex(sid);
    return services[serviceIndex].versions.length;
  }

  // Throw if service not found
  function getServicePurchasesCount(bytes32 sid) external view returns (uint) {
    uint serviceIndex = getServiceIndex(sid);
    return services[serviceIndex].purchases.length;
  }

  // Throw if service not found
  function getServiceOffersCount(bytes32 sid) external view returns (uint) {
    uint serviceIndex = getServiceIndex(sid);
    return services[serviceIndex].offers.length;
  }

  // ------------------------------------------------------
  // Setter functions
  // ------------------------------------------------------

  // Manage Service

  // Throw if sid already exist
  function createService (bytes32 sid) external whenNotPaused returns (uint serviceIndex) {
    require(!isServiceSidExist(sid), "Service's sid is already used");
    services.length++;
    Service storage service = services[services.length - 1];
    service.sid = sid;
    service.owner = msg.sender;
    sidToService[sid] = services.length - 1;
    emit ServiceCreated(
      sid,
      service.owner
    );
    return services.length - 1;
  }

  // Throw if service not found
  // Throw if service owner is not the sender
  // Throw if new owner address is 0
  // Throw if new owner is current owner
  function transferServiceOwnership (bytes32 sid, address newOwner) external whenNotPaused onlyServiceOwner(sid) {
    require(newOwner != address(0), "New Owner cannot be address 0");
    uint serviceIndex = getServiceIndex(sid);
    Service storage service = services[serviceIndex];
    require(newOwner != service.owner, "New Owner is already current owner");
    emit ServiceOwnershipTransferred(
      sid,
      service.owner,
      newOwner
    );
    service.owner = newOwner;
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
    uint serviceIndex = getServiceIndex(sid);
    require(!isServiceHashExist(hash), "Version's hash already exists");
    services[serviceIndex].versions.push(Version({
      hash: hash,
      metadata: metadata
    }));
    uint _versionIndex = services[serviceIndex].versions.length - 1;
    hashToVersion[hash] = VersionIndexes(
      serviceIndex,
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
    uint serviceIndex = getServiceIndex(sid);
    services[serviceIndex].offers.push(Offer({
      price: price,
      duration: duration,
      active: true
    }));
    uint _offerIndex = services[serviceIndex].offers.length - 1;
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
  function disableServiceOffer (bytes32 sid, uint offerIndex)
    external
    whenNotPaused
    onlyServiceOwner(sid)
  returns (uint _offerIndex) {
    uint serviceIndex = getServiceIndex(sid);
    services[serviceIndex].offers[offerIndex].active = false;
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
    (, uint expirationDate) = getServicePurchase(sid, msg.sender);
    return expirationDate >= now;
  }

  // Throw if service not found
  // Throw if offer is disable
  // Throw if sender doesn't have enough balance
  // Throw if sender didn't approve the contract on the ERC20
  function purchase(bytes32 sid, uint offerIndex) external whenNotPaused returns (uint purchaseIndex) {
    uint _serviceIndex = getServiceIndex(sid);
    Service storage service = services[_serviceIndex];
    Offer storage offer = service.offers[offerIndex];
    // TODO: add error if offerIndex doesn't exist!

    // Check if offer is active, sender has enough balance and approved the transform
    require(offer.active, "Cannot purchase a disabled offer");
    require(token.balanceOf(msg.sender) >= offer.price, "Sender doesn't have enough balance to pay this service");
    require(
      token.allowance(msg.sender, address(this)) >= offer.price,
      "Sender didn't approve this contract to spend on his behalf. Execute approve function on the token contract"
    );

    // Transfer the token from sender to service owner
    token.transferFrom(msg.sender, service.owner, offer.price);

    // Calculate expiration date
    uint _expirationDate = now;
    uint _purchaseIndex;
    if (isServicePurchaseExist(sid, msg.sender)) {
      // If already purchased, update expiration
      (, _purchaseIndex) = getServicePurchaseIndexes(sid, msg.sender);
      Purchase storage _purchase = service.purchases[_purchaseIndex];
      // If current expiration date is later than now, use it
      if (_purchase.expirationDate > _expirationDate) {
        _expirationDate = _purchase.expirationDate;
      }
      _expirationDate = _expirationDate + offer.duration;
      _purchase.expirationDate = _expirationDate;
    }
    else {
      // Create new purchase
      _expirationDate = _expirationDate + offer.duration;
      service.purchases.push(Purchase({
        purchaser: msg.sender,
        expirationDate: _expirationDate
      }));
      _purchaseIndex = service.purchases.length - 1;
      purchaserToSidToPurchase[msg.sender][sid] = _purchaseIndex;
    }

    // Emit event
    emit ServicePurchased(
      sid,
      offerIndex,
      msg.sender,
      offer.price,
      offer.duration,
      _expirationDate
    );
    return _purchaseIndex;
  }
}
