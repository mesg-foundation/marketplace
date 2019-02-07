pragma solidity >=0.5.0 <0.6.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

contract Marketplace is Ownable, Pausable {
  struct Service {
    address owner;

    mapping(bytes20 => Version) versions; // version's hash => Version
    bytes20[] versionsList;

    Offer[] offers;

    mapping(address => Purchase) purchases; // purchaser's address => Purchase
    address[] purchasesList;
  }

  struct Purchase {
    uint expire;
  }

  struct Version {
    bytes metadata;
  }

  struct Offer {
    uint price;
    uint duration;
    bool active;
  }

  IERC20 public token;

  mapping(bytes20 => bytes32) public hashToService; // version's hash => service's sid

  mapping(bytes32 => Service) public services; // service's sid => Service
  bytes32[] public servicesList;

  constructor(IERC20 _token) public {
    token = _token;
  }

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
    bytes20 indexed hash,
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
    uint duration,
    uint expire
  );

  function isBytesZero(bytes memory b) pure internal returns (bool) {
    if (b.length == 0) {
      return true;
    }
    bytes memory zero = new bytes(b.length);
    return keccak256(b) == keccak256(zero);
  }

  modifier addressNotZero(address a) {
    require(a != address(0), "Address cannot be set to zero");
    _;
  }

  modifier whenServiceExist(bytes32 sid) {
    require(services[sid].owner != address(0), "Service with this sid does not exist");
    _;
  }

  modifier whenServiceNotExist(bytes32 sid) {
    require(services[sid].owner == address(0), "Service with same sid already exists");
    _;
  }

  modifier onlyServiceOwner(bytes32 sid) {
    require(services[sid].owner == msg.sender, "Service owner is not the sender");
    _;
  }

  modifier notServiceOwner(bytes32 sid) {
    require(services[sid].owner != msg.sender, "Service owner cannot be the sender");
    _;
  }

  modifier whenServiceHashNotExist(bytes20 hash) {
    require(services[hashToService[hash]].owner == address(0), "Hash already exists");
    _;
  }

  modifier whenServiceVersionNotEmpty(bytes32 sid) {
    require(services[sid].versionsList.length > 0, "Cannot create an offer on a service without version");
    _;
  }

  modifier whenServiceOfferExist(bytes32 sid, uint offerIndex) {
    require(offerIndex < services[sid].offers.length, "Service offer does not exist");
    _;
  }

  modifier whenServiceOfferActive(bytes32 sid, uint offerIndex) {
    require(services[sid].offers[offerIndex].active, "Service offer is not active");
    _;
  }

  function getServicesListCount() external view returns (uint count) {
    return servicesList.length;
  }

  function getServicesVersionsListCount(bytes32 sid) external view whenServiceExist(sid) returns (uint count) {
    return services[sid].versionsList.length;
  }

  function getServicesVersion(bytes32 sid, bytes20 hash) external view whenServiceExist(sid) returns (bytes memory metadata) {
    return services[sid].versions[hash].metadata;
  }

  function getServicesOffersCount(bytes32 sid) external view whenServiceExist(sid) returns (uint count) {
    return services[sid].offers.length;
  }

  function getServicesOffer(bytes32 sid, uint offerIndex) external view whenServiceExist(sid) returns (uint price, uint duration, bool active) {
    Offer storage offer = services[sid].offers[offerIndex];
    return (offer.price, offer.duration, offer.active);
  }

  function getServicesPurchasesListCount(bytes32 sid) external view whenServiceExist(sid) returns (uint count) {
    return services[sid].purchasesList.length;
  }

  function getServicesPurchases(bytes32 sid, address purchaser) external view whenServiceExist(sid) returns (uint expire) {
    return services[sid].purchases[purchaser].expire;
  }

  function createService(bytes32 sid) external whenNotPaused whenServiceNotExist(sid) {
    require(sid != bytes32(0), "Sid cannot be empty");
    services[sid].owner = msg.sender;
    servicesList.push(sid);
    emit ServiceCreated(sid, msg.sender);
  }

  function transferServiceOwnership(bytes32 sid, address newOwner) external whenNotPaused onlyServiceOwner(sid) addressNotZero(newOwner) {
    emit ServiceOwnershipTransferred(sid, services[sid].owner, newOwner);
    services[sid].owner = newOwner;
  }

  function createServiceVersion(bytes32 sid, bytes20 hash, bytes calldata metadata) external whenNotPaused onlyServiceOwner(sid) whenServiceHashNotExist(hash) {
    require(!isBytesZero(metadata), "Metadata cannot be empty");
    services[sid].versions[hash].metadata = metadata;
    services[sid].versionsList.push(hash);
    hashToService[hash] = sid;
    emit ServiceVersionCreated(sid, hash, metadata);
  }

  function createServiceOffer(bytes32 sid, uint price, uint duration) external whenNotPaused onlyServiceOwner(sid) whenServiceVersionNotEmpty(sid) returns (uint offerIndex) {
    require(duration > 0, "Duration cannot be zero");
    Offer[] storage offers = services[sid].offers;
    offers.push(Offer({
      price: price,
      duration: duration,
      active: true
    }));
    emit ServiceOfferCreated(sid, offers.length - 1, price, duration);
    return offers.length - 1;
  }

  function disableServiceOffer(bytes32 sid, uint offerIndex) external whenNotPaused onlyServiceOwner(sid) whenServiceOfferExist(sid, offerIndex) {
    services[sid].offers[offerIndex].active = false;
    emit ServiceOfferDisabled(sid, offerIndex);
  }

  function isAuthorized(bytes32 sid) external view returns (bool purchased) {
    return services[sid].owner == msg.sender || services[sid].purchases[msg.sender].expire >= now;
  }

  function purchase(bytes32 sid, uint offerIndex) external whenNotPaused whenServiceExist(sid) notServiceOwner(sid) whenServiceOfferExist(sid, offerIndex) whenServiceOfferActive(sid, offerIndex) {
    Service storage service = services[sid];
    Offer storage offer = service.offers[offerIndex];

    // Check if offer is active, sender has enough balance and approved the transform
    require(token.balanceOf(msg.sender) >= offer.price, "Sender does not have enough balance to pay this service");
    require(token.allowance(msg.sender, address(this)) >= offer.price, "Sender did not approve this contract to spend on his behalf. Execute approve function on the token contract");

    // Transfer the token from sender to service owner
    token.transferFrom(msg.sender, service.owner, offer.price);

    uint expire = now + offer.duration;
    if (service.purchases[msg.sender].expire > now) {
      expire = service.purchases[msg.sender].expire + offer.duration;
    }

    service.purchases[msg.sender].expire = expire;
    service.purchasesList.push(msg.sender); // TODO: user can purchase multiple time
    emit ServicePurchased(sid, offerIndex, msg.sender, offer.price, offer.duration, expire);
  }
}
