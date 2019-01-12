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

  // TODO: indexed on bytes20 transform it as bytes32
  // TODO: indexed on bytes transform it to something else
  // TODO: apply same logic for event data and index
  event ServiceCreated(uint serviceIndex, bytes sid, address indexed owner, uint price);

  event ServiceOwnershipTransferred(uint serviceIndex, bytes sid, address indexed previousOwner, address indexed newOwner);

  event ServicePriceChanged(uint serviceIndex, bytes sid, uint previousPrice, uint newPrice);

  event ServiceVersionCreated(uint serviceIndex, bytes20 hash, bytes url);

  event ServicePaid(uint serviceIndex, bytes sid, address indexed purchaser, address indexed seller, uint price);

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

  function compareBytes(bytes memory a, bytes memory b) internal pure returns (bool) {
    return keccak256(a) == keccak256(b);
  }

  // ------------------------------------------------------
  // View functions
  // ------------------------------------------------------

  // TODO: have to create getter for version and payment because services auto-generated getter doesn't return array of struct
  function getServiceVersion(uint serviceIndex, uint versionIndex) public view returns (bytes20 hash, bytes memory url) {
    Version storage version = services[serviceIndex].versions[versionIndex];
    return (version.hash, version.url);
  }

  function getServicePayment(uint serviceIndex, uint paymentIndex) public view returns (address purchaser) {
    Payment storage payment = services[serviceIndex].payments[paymentIndex];
    return payment.purchaser;
  }

  // Index

  function getServiceIndex(bytes memory sid) public view returns (uint serviceIndex) {
    for (uint i = 0; i < services.length; i++) {
      if (compareBytes(services[i].sid, sid)) {
        return i;
      }
    }
    require(false, "Service not found");
  }

  function getServiceVersionIndex(uint serviceIndex, bytes20 hash) public view returns (uint versionIndex) {
    Service storage service = services[serviceIndex];
    for (uint i = 0; i < service.versions.length; i++) {
      if (service.versions[i].hash == hash) {
        return i;
      }
    }
    require(false, "Version not found");
  }

  function getServicePaymentIndex(uint serviceIndex, address purchaser) public view returns (uint paymentIndex) {
    Service storage service = services[serviceIndex];
    for (uint i = 0; i < service.payments.length; i++) {
      if (service.payments[i].purchaser == purchaser) {
        return i;
      }
    }
    require(false, "Payment not found");
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
      require(!compareBytes(services[i].sid, sid), "Sid is already used");
    }
    services.length++;
    Service storage service = services[services.length - 1];
    service.sid = sid;
    service.price = price;
    service.owner = msg.sender;
    emit ServiceCreated(services.length - 1, service.sid, service.owner, service.price);
    return services.length - 1;
  }

  function transferServiceOwnership (uint serviceIndex, address payable newOwner) public whenNotPaused {
    Service storage service = services[serviceIndex];
    checkServiceOwner(service);
    emit ServiceOwnershipTransferred(serviceIndex, service.sid, service.owner, newOwner);
    service.owner = newOwner;
  }

  function changeServicePrice (uint serviceIndex, uint newPrice) public whenNotPaused {
    Service storage service = services[serviceIndex];
    checkServiceOwner(service);
    emit ServicePriceChanged(serviceIndex, service.sid, service.price, newPrice);
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
    emit ServiceVersionCreated(serviceIndex, hash, url);
    return service.versions.length - 1;
  }

  // ------------------------------------------------------
  // Payment
  // ------------------------------------------------------

  function hasPaid(uint serviceIndex) public view returns (bool paid) {
    Service storage service = services[serviceIndex];
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
    emit ServicePaid(serviceIndex, service.sid, msg.sender, service.owner, service.price);
    return service.payments.length - 1;
  }
}
