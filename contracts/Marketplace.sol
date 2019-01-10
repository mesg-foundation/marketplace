pragma solidity >=0.5.2 <0.6.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";

contract Marketplace is Ownable, Pausable {
  // ------------------------------------------------------
  // Structures
  // ------------------------------------------------------

  struct Service {
    address owner;
    string sid;
    Version[] versions;
    Offer[] offers;
    Payment[] payments;
  }

  struct Version {
    string hash;
    string url;
  }

  struct Offer {
    uint price;
    // address payment; // TODO: to implement later
    address seller;
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

  function checkServiceOwner(Service service) private pure {
    require(service.owner == msg.sender, "Service owner is not the same as the sender");
  }

  // ------------------------------------------------------
  // View functions
  // ------------------------------------------------------

  // Manage Service

  function getService(string memory sid) public view returns (Service memory service) {
    for (uint i = 0; i < services.length; i++) {
      if (services[i].sid == sid) {
        return services[i];
      }
    }
    // TODO: should throw an error?
  }

  function getServicesCount() public view returns (uint servicesCount) {
    return services.length;
  }

  // Manage Version

  // is it useful? i think by hash is better
  // function getServiceVersion(string memory sid, uint versionIndex) public view returns (Version memory version) {
  //   Service memory service = getService(sid);
  //   // TODO: assert sid exist
  //   // TODO: assert version exist
  //   return services.versions[versionIndex];
  // }

  function getServiceVersion(string memory sid, string memory hash) public view returns (Version memory version) {
    Service memory service = getService(sid);
    for (uint i = 0; i < service.versions.length; i++) {
      if (service.versions[i].hash == hash) {
        return service.versions[i];
      }
    }
    // TODO: should throw an error?
  }

  function getLastServiceVersion(string memory sid) public view returns (Version memory version) {
    Service memory service = getService(sid);
    require(service.versions.length >= 1, "No version in this service");
    return service.versions[service.versions.length - 1];
  }

  function getServiceVersionsCount(string memory sid) public view returns (uint serviceVersionsCount) {
    Service memory service = getService(sid);
    return service.versions.length;
  }

  // Manage Offer

  function getServiceOffer(string memory sid, uint offerIndex) public view returns (Offer memory offer) {
    Service memory service = getService(sid);
    // TODO: assert sid exist
    // TODO: assert offer exist
    return services.offers[offerIndex];
  }

  function getServiceOffersCount(string memory sid) public view returns (uint serviceOffersCount) {
    Service memory service = getService(sid);
    return service.offers.length;
  }

  // Manage Payment

  function getServicePayment(string memory sid, uint paymentIndex) public view returns (Payment memory payment) {
    Service memory service = getService(sid);
    // TODO: assert sid exist
    // TODO: assert payment exist
    return services.payments[paymentIndex];
  }

  function getServicePaymentsCount(string memory sid) public view returns (uint servicePaymentsCount) {
    Service memory service = getService(sid);
    return service.payments.length;
  }

  // ------------------------------------------------------
  // Modifier functions
  // ------------------------------------------------------

  // Manage Service

  function addService (string memory sid) public returns (uint serviceIndex) {
    Service memory service = getService(sid);
    require(service.sid == "", "Sid is already used");
    // services.length++; //is it really useful?
    // Service storage s = services[services.length - 1];
    // s.sid = sid;
    // s.owner = msg.sender;
    services.push(Service({
      sid: sid,
      owner: msg.sender
    }));
    return services.length - 1;
  }

  function changeServiceOwner (string memory sid, address newOwner) public {
    Service memory service = getService(sid);
    checkServiceOwner(service);
    service.owner = newOwner;
  }

  // Manage Version

  function addServiceVersion (string memory sid, string memory hash, string memory url) public returns (uint versionIndex) {
    Service memory service = getService(sid);
    checkServiceOwner(service);
    service.versions.push(Version({
      hash: hash,
      url: url
    }));
    return service.versions.length - 1;
  }

  // Manage Offer

  function addServiceOffer (string memory sid, uint price, address seller, bool active) public returns (uint offerIndex) {
    Service memory service = getService(sid);
    checkServiceOwner(service);
    service.offers.push(Offer({
      price: price,
      seller: seller,
      active: active
    }));
    return service.offers.length - 1;
  }

  function editServiceOffer (string memory sid, uint offerIndex, bool active) public {
    Service memory service = getService(sid);
    checkServiceOwner(service);
    service.offers[offerIndex].active = active;
  }

  // ------------------------------------------------------
  // Payment
  // ------------------------------------------------------

  function verify(string sid) public returns (bool isPaid) {
    Service memory service = getService(sid);
    for (uint i = 0; i < service.payments.length; i++) {
      if (service.payments[i].purchaser == msg.sender) {
        return true;
      }
    }
    return false;
  }

  function pay(string sid, uint offerIndex) public payable returns (uint paymentIndex) {
    Offer memory offer = getServiceOffer(sid, offerIndex);
    require(offer.active, "The offer is not active");
    require(offer.price == msg.value, "The offer price is different than the value of this transaction");
    offer.seller.transfer(offer.price);
    service.payments.push(Payment({
      offerIndex: offerIndex,
      purchaser: msg.sender
    }));
    return service.payments.length - 1;
  }
}
