pragma solidity >=0.5.0 <0.6.0;

import "../node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../node_modules/openzeppelin-solidity/contracts/lifecycle/Pausable.sol";

contract Marketplace is Ownable, Pausable {
  // ------------------------------------------------------
  // Structures
  // ------------------------------------------------------

  struct Service {
    address owner;
    bytes sid;
    Version[] versions;
    Offer[] offers;
    Payment[] payments;
  }

  struct Version {
    bytes20 hash;
    bytes url;
  }

  struct Offer {
    uint price;
    // address payment; // TODO: to implement later
    address payable seller;
    bool active;
  }

  struct Payment {
    uint offerIndex;
    address purchaser;
  }

  // ------------------------------------------------------
  // TODO: Events
  // ------------------------------------------------------

  // ------------------------------------------------------
  // State variables
  // ------------------------------------------------------

  Service[] public services; //TODO: shouldn't it be private?

  // ------------------------------------------------------
  // Constructor
  // ------------------------------------------------------

  constructor() public {}

  // ------------------------------------------------------
  // Check functions
  // ------------------------------------------------------

  function checkServiceOwner(Service memory service) private view {
    require(service.owner == msg.sender, "Service owner is not the same as the sender");
  }

  // ------------------------------------------------------
  // Utils functions
  // ------------------------------------------------------

  function compare(bytes memory a, bytes memory b) internal pure returns (bool) {
    return keccak256(a) == keccak256(b);
  }

  // ------------------------------------------------------
  // View functions
  // ------------------------------------------------------

  // Manage Service

  function getServiceIndexRaw(bytes memory sid) public view returns (int serviceIndex) {
    for (uint i = 0; i < services.length; i++) {
      if (compare(services[i].sid, sid)) {
        return int(i);
      }
    }
    return -1;
  }

  function getServiceIndex(bytes memory sid) public view returns (uint serviceIndex) {
    int _serviceIndex = getServiceIndexRaw(sid);
    require(_serviceIndex >= 0, "Service not found");
    return uint(_serviceIndex);
  }

  function getServicesCount() public view returns (uint servicesCount) {
    return services.length;
  }

  // Manage Version

  // is it useful? i think by hash is better
  // function getServiceVersion(bytes memory sid, uint versionIndex) public view returns (Version memory version) {
  //   Service memory service = getService(sid);
  //   // TODO: assert sid exist
  //   // TODO: assert version exist
  //   return services.versions[versionIndex];
  // }

  // function getServiceVersion(bytes memory sid, bytes20 hash) public view returns (Version memory version) {
  //   Service memory service = getService(sid);
  //   for (uint i = 0; i < service.versions.length; i++) {
  //     if (service.versions[i].hash == hash) {
  //       return service.versions[i];
  //     }
  //   }
  //   // TODO: should throw an error?
  // }

  function getServiceVersionIndex(bytes memory sid, bytes20 hash) public view returns (int versionIndex) {
    uint serviceIndex = getServiceIndex(sid);
    Service memory service = services[serviceIndex];
    for (uint i = 0; i < service.versions.length; i++) {
      if (service.versions[i].hash == hash) {
        return int(i);
      }
    }
    return -1;
  }

  // function getLastServiceVersion(bytes memory sid) public view returns (Version memory version) {
  //   Service memory service = getService(sid);
  //   require(service.versions.length >= 1, "No version in this service");
  //   return service.versions[service.versions.length - 1];
  // }

  function getServiceVersionsCount(bytes memory sid) public view returns (uint serviceVersionsCount) {
    uint serviceIndex = getServiceIndex(sid);
    Service memory service = services[serviceIndex];
    return service.versions.length;
  }

  // Manage Offer

  // function getServiceOffer(bytes memory sid, uint offerIndex) public view returns (Offer memory offer) {
  //   int serviceIndex = getService(sid);
  //   Service memory service = services[serviceIndex];
  //   // TODO: assert sid exist
  //   // TODO: assert offer exist
  //   return services.offers[offerIndex];
  // }

  function getServiceOffersCount(bytes memory sid) public view returns (uint serviceOffersCount) {
    uint serviceIndex = getServiceIndex(sid);
    Service memory service = services[serviceIndex];
    return service.offers.length;
  }

  // Manage Payment

  // function getServicePayment(bytes memory sid, uint paymentIndex) public view returns (Payment memory payment) {
  //   uint serviceIndex = getServiceIndex(sid);
  //   Service memory service = services[serviceIndex];
  //   // TODO: assert sid exist
  //   // TODO: assert payment exist
  //   return services.payments[paymentIndex];
  // }

  function getServicePaymentsCount(bytes memory sid) public view returns (uint servicePaymentsCount) {
    uint serviceIndex = getServiceIndex(sid);
    Service memory service = services[serviceIndex];
    return service.payments.length;
  }

  // ------------------------------------------------------
  // Setter functions
  // ------------------------------------------------------

  // Manage Service

  function createService (bytes memory sid) public whenNotPaused returns (uint serviceIndex) {
    int _serviceIndex = getServiceIndexRaw(sid);
    require(_serviceIndex == -1, "Sid is already used");

    services.length++;
    Service storage service = services[services.length - 1];
    service.sid = sid;
    service.owner = msg.sender;
    
    // The following doesn't work but seems cleaner than the previous
    // Version[] storage versions = new Version[](0);
    // Offer[] storage offers = new Offer[](0);
    // Payment[] storage payments = new Payment[](0);
    // Service storage service = Service({
    //   sid: sid,
    //   owner: msg.sender,
    //   versions: versions,
    //   offers: offers,
    //   payments: payments
    // });
    // services.push(service);

    emit ServiceCreated(service.owner, service.sid, services.length - 1);

    return services.length - 1;
  }

  event ServiceCreated(address indexed owner, bytes indexed sid, uint indexed serviceIndex);

  function changeServiceOwner (bytes memory sid, address newOwner) public whenNotPaused {
    uint serviceIndex = getServiceIndex(sid);
    Service storage service = services[serviceIndex];
    checkServiceOwner(service);
    service.owner = newOwner;
  }

  // Manage Version

  function createServiceVersion (bytes memory sid, bytes20 hash, bytes memory url) public whenNotPaused returns (uint versionIndex) {
    uint serviceIndex = getServiceIndex(sid);
    Service storage service = services[serviceIndex];
    checkServiceOwner(service);
    service.versions.push(Version({
      hash: hash,
      url: url
    }));
    return service.versions.length - 1;
  }

  // Manage Offer

  function createServiceOffer (bytes memory sid, uint price, address payable seller, bool active) public whenNotPaused returns (uint offerIndex) {
    uint serviceIndex = getServiceIndex(sid);
    Service storage service = services[serviceIndex];
    checkServiceOwner(service);
    service.offers.push(Offer({
      price: price,
      seller: seller,
      active: active
    }));
    return service.offers.length - 1;
  }

  function editServiceOffer (bytes memory sid, uint offerIndex, bool active) public whenNotPaused {
    uint serviceIndex = getServiceIndex(sid);
    Service storage service = services[serviceIndex];
    checkServiceOwner(service);
    service.offers[offerIndex].active = active;
  }

  // ------------------------------------------------------
  // Payment
  // ------------------------------------------------------

  function verify(bytes memory sid) public view returns (bool isPaid) {
    uint serviceIndex = getServiceIndex(sid);
    Service memory service = services[serviceIndex];
    for (uint i = 0; i < service.payments.length; i++) {
      if (service.payments[i].purchaser == msg.sender) {
        return true;
      }
    }
    return false;
  }

  function pay(bytes memory sid, uint offerIndex) public payable whenNotPaused returns (uint paymentIndex) {
    uint serviceIndex = getServiceIndex(sid);
    Service storage service = services[serviceIndex];
    Offer memory offer = service.offers[offerIndex];
    require(offer.active, "The offer is not active");
    require(offer.price == msg.value, "The offer price is different than the value of this transaction");
    offer.seller.transfer(msg.value);
    service.payments.push(Payment({
      offerIndex: offerIndex,
      purchaser: msg.sender
    }));
    return service.payments.length - 1;
  }
}
