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
    uint date;
    uint offerIndex;
  }

  struct Offer {
    uint price;
    uint duration;
    bool active;
  }

  struct VersionIndex {
    uint serviceIndex;
    uint versionIndex;
  }

  struct PurchaseIndex {
    uint serviceIndex;
    uint purchaseIndex;
  }

  // ------------------------------------------------------
  // State variables
  // ------------------------------------------------------

  Service[] public services;
  mapping(bytes32 => uint) public servicesSid;
  mapping(bytes20 => VersionIndex) public versionsIndex;
  mapping(address => PurchaseIndex[]) public purchasesIndex;

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
    uint indexed serviceIndex,
    bytes32 indexed sid,
    address indexed owner
  );

  event ServiceOwnershipTransferred(
    uint indexed serviceIndex,
    bytes32 sid,
    address indexed previousOwner,
    address indexed newOwner
  );

  event ServiceVersionCreated(
    uint indexed serviceIndex,
    bytes32 indexed sid,
    uint indexed versionIndex,
    bytes20 hash,
    bytes metadata
  );

  event ServiceOfferCreated(
    uint indexed serviceIndex,
    bytes32 indexed sid,
    uint indexed offerIndex,
    uint price,
    uint duration
  );

  event ServiceOfferDisabled(
    uint indexed serviceIndex,
    bytes32 indexed sid,
    uint indexed offerIndex
  );

  event ServicePurchased(
    uint indexed serviceIndex,
    bytes32 sid,
    uint indexed offerIndex,
    address indexed purchaser,
    uint price,
    uint duration
  );

  // ------------------------------------------------------
  // Modifier functions
  // ------------------------------------------------------

  modifier onlyServiceOwner(uint serviceIndex) {
    require(isServiceOwner(serviceIndex), "Service owner is not the same as the sender");
    _;
  }

  // ------------------------------------------------------
  // View functions
  // ------------------------------------------------------

  function isServiceOwner(uint serviceIndex) public view returns (bool) {
    return services[serviceIndex].owner == msg.sender;
  }

  function isServiceSidExist(bytes32 sid) public view returns (bool) {
    // if (services[servicesSid[sid]].sid == sid) {
    for (uint i = 0; i < services.length; i++) {
      if (services[i].sid == sid) {
        return true;
      }
    }
    return false;
  }

  function isServiceHashExist(bytes20 hash) public view returns (bool) {
    for (uint serviceIndex = 0; serviceIndex < services.length; serviceIndex++) {
      for (uint versionIndex = 0; versionIndex < services[serviceIndex].versions.length; versionIndex++) {
        if (services[serviceIndex].versions[versionIndex].hash == hash) {
          return true;
        }
      }
    }
    return false;
  }

  // Getters

  function getServiceVersion(uint serviceIndex, uint versionIndex) external view returns (bytes20 hash, bytes memory metadata) {
    Version storage version = services[serviceIndex].versions[versionIndex];
    return (version.hash, version.metadata);
  }

  function getServicePurchase(uint serviceIndex, uint purchaseIndex) external view returns (address purchaser, uint date, uint offerIndex) {
    Purchase storage purchase = services[serviceIndex].purchases[purchaseIndex];
    return (purchase.purchaser, purchase.date, purchase.offerIndex);
  }

  function getServiceOffer(uint serviceIndex, uint offerIndex) external view returns (uint price, uint duration, bool active) {
    Offer storage offer = services[serviceIndex].offers[offerIndex];
    return (offer.price, offer.duration, offer.active);
  }

  // Index

  function getServiceIndex(bytes32 sid) external view returns (uint) {
    for (uint i = 0; i < services.length; i++) {
      if (services[i].sid == sid) {
        return i;
      }
    }
    require(false, "Service not found");
  }

  function getServiceVersionIndex(uint serviceIndex, bytes20 hash) external view returns (uint) {
    Service storage service = services[serviceIndex];
    for (uint i = 0; i < service.versions.length; i++) {
      if (service.versions[i].hash == hash) {
        return i;
      }
    }
    require(false, "Version not found");
  }

  function getServicePurchaseIndex(uint serviceIndex, address purchaser) external view returns (uint) {
    Service storage service = services[serviceIndex];
    for (uint i = 0; i < service.purchases.length; i++) {
      if (service.purchases[i].purchaser == purchaser) {
        return i;
      }
    }
    require(false, "Purchase not found");
  }

  // Count

  function getServicesCount() external view returns (uint) {
    return services.length;
  }

  function getServiceVersionsCount(uint serviceIndex) external view returns (uint) {
    return services[serviceIndex].versions.length;
  }

  function getServicePurchasesCount(uint serviceIndex) external view returns (uint) {
    return services[serviceIndex].purchases.length;
  }

  function getServiceOffersCount(uint serviceIndex) external view returns (uint) {
    return services[serviceIndex].offers.length;
  }

  // ------------------------------------------------------
  // Setter functions
  // ------------------------------------------------------

  // Manage Service

  function createService (bytes32 sid) external whenNotPaused returns (uint serviceIndex) {
    require(!isServiceSidExist(sid), "Service's sid is already used");
    services.length++;
    Service storage service = services[services.length - 1];
    service.sid = sid;
    service.owner = msg.sender;
    emit ServiceCreated(
      services.length - 1,
      service.sid,
      service.owner
    );
    return services.length - 1;
  }

  function transferServiceOwnership (uint serviceIndex, address newOwner) external whenNotPaused onlyServiceOwner(serviceIndex) {
    require(newOwner != address(0), "New Owner cannot be address 0");
    Service storage service = services[serviceIndex];
    require(newOwner != service.owner, "New Owner is already current owner");
    emit ServiceOwnershipTransferred(
      serviceIndex,
      service.sid,
      service.owner,
      newOwner
    );
    service.owner = newOwner;
  }

  // Manage Version

  function createServiceVersion (uint serviceIndex, bytes20 hash, bytes calldata metadata)
    external
    whenNotPaused
    onlyServiceOwner(serviceIndex)
  returns (uint versionIndex) {
    require(!isServiceHashExist(hash), "Version's hash already exists");
    Service storage service = services[serviceIndex];
    service.versions.push(Version({
      hash: hash,
      metadata: metadata
    }));
    uint _versionIndex = service.versions.length - 1;
    emit ServiceVersionCreated(
      serviceIndex,
      service.sid,
      _versionIndex,
      hash,
      metadata
    );
    return _versionIndex;
  }

  // Manage Offer

  function createServiceOffer (uint serviceIndex, uint price, uint duration)
    external
    whenNotPaused
    onlyServiceOwner(serviceIndex)
  returns (uint offerIndex) {
    Service storage service = services[serviceIndex];
    service.offers.push(Offer({
      price: price,
      duration: duration,
      active: true
    }));
    uint _offerIndex = service.offers.length - 1;
    emit ServiceOfferCreated(
      serviceIndex,
      service.sid,
      _offerIndex,
      price,
      duration
    );
    return _offerIndex;
  }

  function disableServiceOffer (uint serviceIndex, uint offerIndex)
    external
    whenNotPaused
    onlyServiceOwner(serviceIndex)
  returns (uint _offerIndex) {
    services[serviceIndex].offers[offerIndex].active = false;
    emit ServiceOfferDisabled(
      serviceIndex,
      services[serviceIndex].sid,
      offerIndex
    );
    return offerIndex;
  }

  // ------------------------------------------------------
  // Purchase
  // ------------------------------------------------------

  function hasPurchased(uint serviceIndex) public view returns (bool purchased) {
    Service storage service = services[serviceIndex];
    for (uint i = 0; i < service.purchases.length; i++) {
      if (service.purchases[i].purchaser == msg.sender) {
        Purchase storage purchase = service.purchases[i];
        Offer storage offer = service.offers[purchase.offerIndex];
        if (purchase.date + offer.duration >= now) {
          return true;
        }
      }
    }
    return false;
  }

  function purchase(uint serviceIndex, uint offerIndex) external whenNotPaused returns (uint purchaseIndex) {
    require(!hasPurchased(serviceIndex), "Sender already purchased this service");
    Service storage service = services[serviceIndex];
    Offer storage offer = services[serviceIndex].offers[offerIndex];
    require(offer.active, "Cannot purchase a disabled offer");
    require(token.balanceOf(msg.sender) >= offer.price, "Sender doesn't have enough balance to pay this service");
    require(
      token.allowance(msg.sender, address(this)) >= offer.price,
      "Sender didn't approve this contract to spend on his behalf. Execute approve function on the token contract"
    );
    token.transferFrom(msg.sender, service.owner, offer.price);
    service.purchases.push(Purchase({
      purchaser: msg.sender,
      date: now,
      offerIndex: offerIndex
    }));
    emit ServicePurchased(
      serviceIndex,
      service.sid,
      offerIndex,
      msg.sender,
      offer.price,
      offer.duration
    );
    return service.purchases.length - 1;
  }
}
