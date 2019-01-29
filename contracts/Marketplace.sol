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

  struct VersionIndexes {
    uint serviceIndex;
    uint versionIndex;
  }

  // struct PurchaseIndexes {
  //   uint serviceIndex;
  //   uint purchaseIndex;
  // }

  // ------------------------------------------------------
  // State variables
  // ------------------------------------------------------

  Service[] public services;
  mapping(bytes32 => uint) public sidToService;
  mapping(bytes20 => VersionIndexes) public hashToVersion;
  // mapping(address => PurchaseIndexes[]) public purchasesIndexes;

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
    uint duration
  );

  // ------------------------------------------------------
  // Modifier functions
  // ------------------------------------------------------

  modifier onlyServiceOwner(bytes32 sid) {
    require(isServiceOwner(sid), "Service owner is not the same as the sender");
    _;
  }

  // ------------------------------------------------------
  // View functions
  // ------------------------------------------------------

  function isServiceOwner(bytes32 sid) public view returns (bool) {
    if (!isServiceSidExist(sid)) {
      return false;
    }
    return services[sidToService[sid]].owner == msg.sender;
  }

  function isServiceSidExist(bytes32 sid) public view returns (bool) {
    if (sidToService[sid] >= services.length) {
      return false;
    }
    return services[sidToService[sid]].sid == sid; // TODO: is this test useful?
  }

  function isServiceHashExist(bytes20 hash) public view returns (bool) {
    VersionIndexes storage indexes = hashToVersion[hash];
    if (indexes.serviceIndex >= services.length) {
      return false;
    }
    if (indexes.versionIndex >= services[indexes.serviceIndex].versions.length) {
      return false;
    }
    return services[indexes.serviceIndex].versions[indexes.versionIndex].hash == hash;
    // for (uint serviceIndex = 0; serviceIndex < services.length; serviceIndex++) {
    //   for (uint versionIndex = 0; versionIndex < services[serviceIndex].versions.length; versionIndex++) {
    //     if (services[serviceIndex].versions[versionIndex].hash == hash) {
    //       return true;
    //     }
    //   }
    // }
    // return false;
  }

  // Getters

  function getServiceVersion(bytes32 sid, uint versionIndex) external view returns (bytes20 hash, bytes memory metadata) {
    Version storage version = services[sidToService[sid]].versions[versionIndex];
    return (version.hash, version.metadata);
  }


  function getServicePurchase(bytes32 sid, uint purchaseIndex) external view returns (address purchaser, uint date, uint offerIndex) {
    Purchase storage purchase = services[sidToService[sid]].purchases[purchaseIndex];
    return (purchase.purchaser, purchase.date, purchase.offerIndex);
  }

  function getServiceOffer(bytes32 sid, uint offerIndex) external view returns (uint price, uint duration, bool active) {
    Offer storage offer = services[sidToService[sid]].offers[offerIndex];
    return (offer.price, offer.duration, offer.active);
  }

  // Index

  // function getServiceIndex(bytes32 sid) external view returns (uint) {
  //   for (uint i = 0; i < services.length; i++) {
  //     if (services[i].sid == sid) {
  //       return i;
  //     }
  //   }
  //   require(false, "Service not found");
  // }

  // function getServiceVersionIndex(uint serviceIndex, bytes20 hash) external view returns (uint) {
  //   Service storage service = services[serviceIndex];
  //   for (uint i = 0; i < service.versions.length; i++) {
  //     if (service.versions[i].hash == hash) {
  //       return i;
  //     }
  //   }
  //   require(false, "Version not found");
  // }

  // TODO: need to change. a purchaser can purchase multiple offer.
  // function getServicePurchaseIndex(bytes32 sid, address purchaser) external view returns (uint) {
  //   Service storage service = services[sidToService[sid]];
  //   for (uint i = 0; i < service.purchases.length; i++) {
  //     if (service.purchases[i].purchaser == purchaser) {
  //       return i;
  //     }
  //   }
  //   require(false, "Purchase not found");
  // }

  // Count

  function getServicesCount() external view returns (uint) {
    return services.length;
  }

  function getServiceVersionsCount(bytes32 sid) external view returns (uint) {
    return services[sidToService[sid]].versions.length;
  }

  function getServicePurchasesCount(bytes32 sid) external view returns (uint) {
    return services[sidToService[sid]].purchases.length;
  }

  function getServiceOffersCount(bytes32 sid) external view returns (uint) {
    return services[sidToService[sid]].offers.length;
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
    sidToService[sid] = services.length - 1;
    emit ServiceCreated(
      sid,
      service.owner
    );
    return services.length - 1;
  }

  function transferServiceOwnership (bytes32 sid, address newOwner) external whenNotPaused onlyServiceOwner(sid) {
    require(newOwner != address(0), "New Owner cannot be address 0");
    Service storage service = services[sidToService[sid]];
    require(newOwner != service.owner, "New Owner is already current owner");
    emit ServiceOwnershipTransferred(
      sid,
      service.owner,
      newOwner
    );
    service.owner = newOwner;
  }

  // Manage Version

  function createServiceVersion (bytes32 sid, bytes20 hash, bytes calldata metadata)
    external
    whenNotPaused
    onlyServiceOwner(sid)
  returns (uint versionIndex) {
    require(!isServiceHashExist(hash), "Version's hash already exists");
    uint serviceIndex = sidToService[sid];
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

  function createServiceOffer (bytes32 sid, uint price, uint duration)
    external
    whenNotPaused
    onlyServiceOwner(sid)
  returns (uint offerIndex) {
    services[sidToService[sid]].offers.push(Offer({
      price: price,
      duration: duration,
      active: true
    }));
    uint _offerIndex = services[sidToService[sid]].offers.length - 1;
    emit ServiceOfferCreated(
      sid,
      _offerIndex,
      price,
      duration
    );
    return _offerIndex;
  }

  function disableServiceOffer (bytes32 sid, uint offerIndex)
    external
    whenNotPaused
    onlyServiceOwner(sid)
  returns (uint _offerIndex) {
    services[sidToService[sid]].offers[offerIndex].active = false;
    emit ServiceOfferDisabled(
      sid,
      offerIndex
    );
    return offerIndex;
  }

  // ------------------------------------------------------
  // Purchase
  // ------------------------------------------------------

  function hasPurchased(bytes32 sid) public view returns (bool purchased) {
    Service storage service = services[sidToService[sid]];
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

  function purchase(bytes32 sid, uint offerIndex) external whenNotPaused returns (uint purchaseIndex) {
    require(!hasPurchased(sid), "Sender already purchased this service"); // TODO: this prevent a purchase in "advance" (before the previous is already expired)
    Service storage service = services[sidToService[sid]];
    Offer storage offer = service.offers[offerIndex];
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
      sid,
      offerIndex,
      msg.sender,
      offer.price,
      offer.duration
    );
    return service.purchases.length - 1;
  }
}
