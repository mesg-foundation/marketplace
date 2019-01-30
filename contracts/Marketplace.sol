pragma solidity >=0.5.0 <0.6.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

contract Marketplace is Ownable, Pausable {
  struct Service {
    address owner;

    mapping(bytes20 => Version) versions;
    bytes20[] versionsList;

    Offer[] offers;

    mapping(address => uint) purchasers;
    address[] purchasersList;
  }

  struct Version {
    bytes metadata;
  }

  struct Offer {
    uint price;
    uint duration;
    bool active;
  }

  IERC20 private token;

  mapping(bytes20 => bool) private hashes;

  mapping(bytes32 => Service) public services;
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
    require(a != address(0), "Address is set to zero");
    _;
  }

  modifier whenServiceExist(bytes32 sid) {
    require(services[sid].owner != address(0), "Service with sid wasn't created");
    _;
  }

  modifier whenServiceNotExist(bytes32 sid) {
    require(services[sid].owner == address(0), "Service  with sid has been already created");
    _;
  }

  modifier onlyServiceOwner(bytes32 sid) {
    require(services[sid].owner == msg.sender, "Service owner is not the same as the sender");
    _;
  }

  modifier notServiceOwner(bytes32 sid) {
    require(services[sid].owner != msg.sender, "Service owner is the same as the sender");
    _;
  }

  modifier whenServiceHashNotExist(bytes20 hash) {
    require(!hashes[hash], "Hash exist");
    _;
  }

  modifier whenServiceVersionNotEmpty(bytes32 sid) {
    require(services[sid].versionsList.length > 0, "Cannot create an offer on a service without version");
    _;
  }

  modifier whenServiceOfferExist(bytes32 sid, uint offerIndex) {
    require(offerIndex < services[sid].offers.length, "Sevice offer not exist");
    _;
  }

  modifier whenServiceOfferActive(bytes32 sid, uint offerIndex) {
    require(services[sid].offers[offerIndex].active, "Sevice offer not active");
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

  function getServicesPurchasersListCount(bytes32 sid) external view whenServiceExist(sid) returns (uint count) {
    return services[sid].purchasersList.length;
  }

  function getServicesPurchasers(bytes32 sid, address purchase) external view whenServiceExist(sid) returns (uint expire) {
    return services[sid].purchasers[purchase];
  }

  function createService(bytes32 sid) external whenNotPaused whenServiceNotExist(sid) {
    services[sid].owner = msg.sender;
    servicesList.push(sid);
    emit ServiceCreated(sid, msg.sender);
  }

  function transferServiceOwnership(bytes32 sid, address newOwner) external whenNotPaused onlyServiceOwner(sid) addressNotZero(newOwner) {
    emit ServiceOwnershipTransferred(sid, services[sid].owner, newOwner);
    services[sid].owner = newOwner;
  }

  function createServiceVersion(bytes32 sid, bytes20 hash, bytes calldata metadata) external whenNotPaused onlyServiceOwner(sid) whenServiceHashNotExist(hash) {
    require(!isBytesZero(metadata), 'metadata is empty');
    services[sid].versions[hash].metadata = metadata;
    services[sid].versionsList.push(hash);
    hashes[hash] = true;
    emit ServiceVersionCreated(sid, hash, metadata);
  }

  function createServiceOffer(bytes32 sid, uint price, uint duration) external whenNotPaused onlyServiceOwner(sid) whenServiceVersionNotEmpty(sid) returns (uint offerIndex) {
    require(price > 0, 'price is 0');
    require(duration > 0, 'duration is 0');
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

  function hasPurchased(bytes32 sid) external view returns (bool purchased) {
    return services[sid].owner == msg.sender || services[sid].purchasers[msg.sender] >= now;
  }

  function purchase(bytes32 sid, uint offerIndex) external whenNotPaused whenServiceExist(sid) notServiceOwner(sid) whenServiceOfferExist(sid, offerIndex) whenServiceOfferActive(sid, offerIndex) {
    Service storage service = services[sid];
    Offer storage offer = service.offers[offerIndex];

    // Check if offer is active, sender has enough balance and approved the transform
    require(token.balanceOf(msg.sender) >= offer.price, "Sender doesn't have enough balance to pay this service");
    require(token.allowance(msg.sender, address(this)) >= offer.price, "Sender didn't approve this contract to spend on his behalf. Execute approve function on the token contract");

    // Transfer the token from sender to service owner
    token.transferFrom(msg.sender, service.owner, offer.price);

    uint expire = now + offer.duration;
    if (service.purchasers[msg.sender] > now) {
      expire = service.purchasers[msg.sender] + offer.duration;
    }

    service.purchasers[msg.sender] = expire;
    service.purchasersList.push(msg.sender);
    emit ServicePurchased(sid, offerIndex, msg.sender, offer.price, offer.duration, expire);
  }
}
