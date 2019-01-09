pragma solidity >=0.5.2 <0.6.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract DBMesgService is Ownable {
  constructor() public {}

  struct Version {
    bytes16 hash;
    bytes url;
  }

  struct Service {
    bytes32 sid;
    Version[] versions;
  }

  Service[] public services;

  function addService (bytes32 sid) public onlyOwner {
    services.length++;
    Service storage s = services[services.length - 1];
    s.sid = sid;
  }

  function addServiceVersion (bytes32 sid, bytes16 hash, bytes memory url) public onlyOwner {
    for (uint i = 0; i < services.length; i++) {
      if (services[i].sid == sid) {
        services[i].versions.push(Version({
          hash: hash,
          url: url
        }));
        break;
      }
    }
  }

  function getServicesCount() public view returns(uint servicesCount) {
    return services.length;
  }

  function getServiceVersion(bytes32 sid, uint index) public view returns(bytes16 hash, bytes memory url) {
    for (uint i = 0; i < services.length; i++) {
      if (services[i].sid == sid) {
        return (services[i].versions[index].hash, services[i].versions[index].url);
      }
    }
  }

  function getServiceVersionsCount(bytes32 sid) public view returns(uint serviceVersionsCount) {
    for (uint i = 0; i < services.length; i++) {
      if (services[i].sid == sid) {
        return services[i].versions.length;
      }
    }
    return 0;
  }
}
