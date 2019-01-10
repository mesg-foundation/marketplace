pragma solidity >=0.5.2 <0.6.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";

contract Marketplace is Ownable, Pausable {
  // ------------------------------------------------------
  // Structures
  // ------------------------------------------------------

  struct Version {
    string hash;
    string url;
  }

  struct Service {
    address owner;
    string sid;
    Version[] versions;
  }

  // ------------------------------------------------------
  // State variables
  // ------------------------------------------------------

  Service[] public services; //TODO: shouldn't it be private?

  // ------------------------------------------------------
  // Constructor
  // ------------------------------------------------------

  constructor() public {}

  // ------------------------------------------------------
  // View functions
  // ------------------------------------------------------

  function getService(string memory sid) public view returns(Service memory service) {
    for (uint i = 0; i < services.length; i++) {
      if (services[i].sid == sid) {
        return services[i];
      }
    }
    // TODO: should throw an error?
  }

  function getServicesCount() public view returns(uint servicesCount) {
    return services.length;
  }

  // is it useful? i think by hash is better
  // function getServiceVersion(string memory sid, uint index) public view returns(Version memory version) {
  //   Service memory service = getService(sid);
  //   // TODO: assert sid exist
  //   // TODO: assert version exist
  //   return services.versions[index];
  // }

  function getServiceVersion(string memory sid, string memory hash) public view returns(Version memory version) {
    Service memory service = getService(sid);
    for (uint i = 0; i < service.versions.length; i++) {
      if (service.versions[i].hash == hash) {
        return service.versions[i];
      }
    }
    // TODO: should throw an error?
  }

  function getLastServiceVersion(string memory sid) public view returns(Version memory version) {
    Service memory service = getService(sid);
    require(service.versions.length >= 1, "No version in this service");
    return service.versions[service.versions.length - 1];
  }

  function getServiceVersionsCount(string memory sid) public view returns(uint serviceVersionsCount) {
    Service memory service = getService(sid);
    return service.versions.length;
  }

  // ------------------------------------------------------
  // Modifier functions
  // ------------------------------------------------------

  function addService (string memory sid) public {
    // TODO: add check if sid is not already used
    services.length++; //is it really useful?
    Service storage s = services[services.length - 1];
    s.sid = sid;
  }

  function addServiceVersion (string memory sid, string memory hash, string memory url) public {
    // TODO: assert sid exist
    Service memory service = getService(sid);
    require(service.owner == msg.sender, "Service owner is not the same as the sender");
    service.versions.push(Version({
      hash: hash,
      url: url
    }));
    // TODO: or return error here
  }
}
