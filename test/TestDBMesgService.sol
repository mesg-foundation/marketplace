pragma solidity >=0.5.2 <0.6.0;

import 'truffle/Assert.sol';
import '../contracts/DBMesgService.sol';

contract TestDBMesgService {
  DBMesgService db;

  bytes32 constant _sid = hex"0014ee511b7b5522f2e2a7df611224e1a79a9ddbf6";
  bytes16 constant _hash = 'v0.0.0';
  bytes constant _url = 'http://github.com/mesg-foundation/core';

  function beforeEach() public {
    db = new DBMesgService();
  }

  function testAddService() public {
    db.addService(_sid);

    Assert.equal(db.getServicesCount(), 1, "invalid services lenght");

    bytes32 sid = db.services(0);
    Assert.equal(sid, _sid, "invalid service sid");
  }

  function testAddServiceVersion() public {
    db.addService(_sid);
    db.addServiceVersion(_sid, _hash, _url);

    Assert.equal(db.getServiceVersionsCount(_sid), 1, "invalid service versions lenght");

    (bytes16 hash, bytes memory url) = db.getServiceVersion(_sid, 0);
    Assert.isTrue(hash == _hash, "invalid service version hash");
    Assert.equal(keccak256(url), keccak256(_url), "invalid service version url");
  }
}
