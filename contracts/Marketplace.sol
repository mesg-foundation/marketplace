pragma solidity >=0.5.0 <0.6.0;

import "../node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../node_modules/openzeppelin-solidity/contracts/lifecycle/Pausable.sol";

contract Marketplace is Ownable, Pausable {
  // ------------------------------------------------------
  // Structures
  // ------------------------------------------------------

  struct Service {
    address payable owner;
    bytes sid;
    uint price;

    Version[] versions;
    Payment[] payments;
  }

  struct Version {
    bytes20 hash;
    bytes url;
  }

  struct Payment {
    address purchaser;
  }

  // ------------------------------------------------------
  // Events
  // ------------------------------------------------------

  event ServiceCreated(uint indexed serviceIndex, bytes indexed sid, address indexed owner, uint price);

  // ------------------------------------------------------
  // State variables
  // ------------------------------------------------------

  Service[] public services;

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

  // Index

  function getServiceIndex(bytes memory sid) public view returns (uint serviceIndex) {
    for (uint i = 0; i < services.length; i++) {
      if (compare(services[i].sid, sid)) {
        return i;
      }
    }
    require(false, "Service not found");
  }

  function getServiceVersionIndex(uint serviceIndex, bytes20 hash) public view returns (uint versionIndex) {
    Service memory service = services[serviceIndex];
    for (uint i = 0; i < service.versions.length; i++) {
      if (service.versions[i].hash == hash) {
        return i;
      }
    }
    require(false, "Service version not found");
  }

  // Count

  function getServicesCount() public view returns (uint servicesCount) {
    return services.length;
  }

  function getServiceVersionsCount(uint serviceIndex) public view returns (uint serviceVersionsCount) {
    return services[serviceIndex].versions.length;
  }

  function getServicePaymentsCount(uint serviceIndex) public view returns (uint servicePaymentsCount) {
    return services[serviceIndex].payments.length;
  }

  // ------------------------------------------------------
  // Setter functions
  // ------------------------------------------------------

  // Manage Service

  function createService (bytes memory sid, uint price) public whenNotPaused returns (uint serviceIndex) {
    for (uint i = 0; i < services.length; i++) {
      require(!compare(services[i].sid, sid), "Sid is already used");
    }

    services.length++;
    Service storage service = services[services.length - 1];
    service.sid = sid;
    service.price = price;
    service.owner = msg.sender;

    emit ServiceCreated(services.length - 1, service.sid, service.owner, service.price);

    return services.length - 1;
  }

  function changeServiceOwner (uint serviceIndex, address payable newOwner) public whenNotPaused {
    Service storage service = services[serviceIndex];
    checkServiceOwner(service);
    service.owner = newOwner;
  }

  function changeServicePrice (uint serviceIndex, uint newPrice) public whenNotPaused {
    Service storage service = services[serviceIndex];
    checkServiceOwner(service);
    service.price = newPrice;
  }

  // Manage Version

  function createServiceVersion (uint serviceIndex, bytes20 hash, bytes memory url) public whenNotPaused returns (uint versionIndex) {
    Service storage service = services[serviceIndex];
    checkServiceOwner(service);
    service.versions.push(Version({
      hash: hash,
      url: url
    }));
    return service.versions.length - 1;
  }

  // ------------------------------------------------------
  // Payment
  // ------------------------------------------------------

  function hasPaid(uint serviceIndex) public view returns (bool paid) {
    Service memory service = services[serviceIndex];
    for (uint i = 0; i < service.payments.length; i++) {
      if (service.payments[i].purchaser == msg.sender) {
        return true;
      }
    }
    return false;
  }

  function pay(uint serviceIndex) public payable whenNotPaused returns (uint paymentIndex) {
    Service storage service = services[serviceIndex];
    require(service.price == msg.value, "The service's price is different than the value of this transaction");
    service.owner.transfer(msg.value);
    service.payments.push(Payment({
      purchaser: msg.sender
    }));
    return service.payments.length - 1;
  }
}
