pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/utils/Address.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";

contract Service is Ownable, Pausable {
    bytes32 public sid;
    bytes32 public latest;
    mapping (bytes32 => Version) public versions;
    mapping (bytes32 => mapping(address => bool)) private _versionAccess;

    struct Version {
        bytes32 id;
        bytes32 location;
        uint256 price;
        bool _exists;
    }

    event VersionCreated(bytes32 sid, bytes32 id, bytes32 location, uint256 price);

    constructor(address creator, bytes32 _sid) Ownable() Pausable() public {
        sid = _sid;
        transferOwnership(creator);
        addPauser(creator);
        renouncePauser();
    }

    function createVersion(bytes32 versionHash, bytes32 location, uint256 price) public onlyOwner whenNotPaused {
        require(!versions[versionHash]._exists, "This version already exists");
        versions[versionHash] = Version({
            id: versionHash,
            location: location,
            price: price,
            _exists: true
        });
        latest = versionHash;
        emit VersionCreated(sid, versionHash, location, price);
        return;
    }

    function requestAccess(bytes32 version) public whenNotPaused {
        require(!_versionAccess[version][msg.sender], "You already have access to this version of the service");
        _versionAccess[version][msg.sender] = true;
        return;
    }

    function hasAccessToVersion(bytes32 version, address user) public view returns (bool) {
        return _versionAccess[version][user];
    }
}

contract Marketplace is Ownable, Pausable {
    using Address for address;

    mapping (bytes32 => address) public serviceContracts;
    bytes32[] public services;
    uint256 public totalServices;
    
    event ServiceCreated(bytes32 sid, address serviceAddress);

    constructor() Ownable() Pausable() public {}

    function createService(bytes32 sid) public whenNotPaused {
        if (serviceContracts[sid].isContract()) {
            return;
        }
        serviceContracts[sid] = new Service(msg.sender, sid);
        services.push(sid);
        totalServices = totalServices + 1;
        emit ServiceCreated(sid, serviceContracts[sid]);
    }
}
