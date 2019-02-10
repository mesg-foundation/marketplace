pragma solidity >=0.5.0 <0.6.0;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev give an account access to this role
     */
    function add(Role storage role, address account) internal {
        require(account != address(0));
        require(!has(role, account));

        role.bearer[account] = true;
    }

    /**
     * @dev remove an account's access to this role
     */
    function remove(Role storage role, address account) internal {
        require(account != address(0));
        require(has(role, account));

        role.bearer[account] = false;
    }

    /**
     * @dev check if an account has this role
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0));
        return role.bearer[account];
    }
}

contract PauserRole {
    using Roles for Roles.Role;

    event PauserAdded(address indexed account);
    event PauserRemoved(address indexed account);

    Roles.Role private _pausers;

    constructor () internal {
        _addPauser(msg.sender);
    }

    modifier onlyPauser() {
        require(isPauser(msg.sender));
        _;
    }

    function isPauser(address account) public view returns (bool) {
        return _pausers.has(account);
    }

    function addPauser(address account) public onlyPauser {
        _addPauser(account);
    }

    function renouncePauser() public {
        _removePauser(msg.sender);
    }

    function _addPauser(address account) internal {
        _pausers.add(account);
        emit PauserAdded(account);
    }

    function _removePauser(address account) internal {
        _pausers.remove(account);
        emit PauserRemoved(account);
    }
}

contract Pausable is PauserRole {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    constructor () internal {
        _paused = false;
    }

    /**
     * @return true if the contract is paused, false otherwise.
     */
    function paused() public view returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!_paused);
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(_paused);
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() public onlyPauser whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() public onlyPauser whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @return the address of the owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * @notice Renouncing to ownership will leave the contract without an owner.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract Marketplace is Ownable, Pausable {

  /**
    Structures
   */

  struct Service {
    address owner;

    mapping(bytes32 => Version) versions; // version's hash => Version
    bytes32[] versionsList;

    Offer[] offers;

    mapping(address => Purchase) purchases; // purchaser's address => Purchase
    address[] purchasesList;
  }

  struct Purchase {
    uint expire;
  }

  struct Version {
    bytes manifest;
    bytes manifestProtocol;
  }

  struct Offer {
    uint price;
    uint duration;
    bool active;
  }

  /**
    State variables
   */

  IERC20 public token;

  mapping(bytes32 => Service) public services; // service's sid => Service
  bytes32[] public servicesList;

  mapping(bytes32 => bytes32) public hashToService; // version's hash => service's sid

  /**
    Constructor
   */

  constructor(IERC20 _token) public {
    token = _token;
  }

  /**
    Events
   */

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
    bytes32 indexed hash,
    bytes manifest,
    bytes manifestProtocol
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

  /**
    Modifiers
   */

  modifier whenAddressNotZero(address a) {
    require(a != address(0), "Address cannot be set to zero");
    _;
  }

  modifier whenSidNotEmpty(bytes32 sid) {
    require(sid != bytes32(0), "Sid cannot be empty");
    _;
  }

  modifier whenManifestNotEmpty(bytes memory manifest) {
    require(!isBytesZero(manifest), "Manifest cannot be empty");
    _;
  }

  modifier whenManifestProtocolNotEmpty(bytes memory manifestProtocol) {
    require(!isBytesZero(manifestProtocol), "Manifest protocol cannot be empty");
    _;
  }

  modifier whenDurationNotZero(uint duration) {
    require(duration > 0, "Duration cannot be zero");
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

  modifier whenServiceHashNotExist(bytes32 hash) {
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

  /**
    Externals
   */

  function createService(bytes32 sid)
    external
    whenNotPaused
    whenSidNotEmpty(sid)
    whenServiceNotExist(sid)
  {
    services[sid].owner = msg.sender;
    servicesList.push(sid);
    emit ServiceCreated(sid, msg.sender);
  }

  function transferServiceOwnership(bytes32 sid, address newOwner)
    external
    whenNotPaused
    onlyServiceOwner(sid)
    whenAddressNotZero(newOwner)
  {
    emit ServiceOwnershipTransferred(sid, services[sid].owner, newOwner);
    services[sid].owner = newOwner;
  }

  function createServiceVersion(
    bytes32 sid,
    bytes32 hash,
    bytes calldata manifest,
    bytes calldata manifestProtocol
  )
    external
    whenNotPaused
    onlyServiceOwner(sid)
    whenServiceHashNotExist(hash)
    whenManifestNotEmpty(manifest)
    whenManifestProtocolNotEmpty(manifestProtocol)
  {
    services[sid].versions[hash].manifest = manifest;
    services[sid].versions[hash].manifestProtocol = manifestProtocol;
    services[sid].versionsList.push(hash);
    hashToService[hash] = sid;
    emit ServiceVersionCreated(sid, hash, manifest, manifestProtocol);
  }

  function createServiceOffer(bytes32 sid, uint price, uint duration)
    external
    whenNotPaused
    onlyServiceOwner(sid)
    whenServiceVersionNotEmpty(sid)
    whenDurationNotZero(duration)
    returns (uint offerIndex)
  {
    Offer[] storage offers = services[sid].offers;
    offers.push(Offer({
      price: price,
      duration: duration,
      active: true
    }));
    emit ServiceOfferCreated(sid, offers.length - 1, price, duration);
    return offers.length - 1;
  }

  function disableServiceOffer(bytes32 sid, uint offerIndex)
    external
    whenNotPaused
    onlyServiceOwner(sid)
    whenServiceOfferExist(sid, offerIndex)
  {
    services[sid].offers[offerIndex].active = false;
    emit ServiceOfferDisabled(sid, offerIndex);
  }

  function purchase(bytes32 sid, uint offerIndex)
    external
    whenNotPaused
    whenServiceExist(sid)
    notServiceOwner(sid)
    whenServiceOfferExist(sid, offerIndex)
    whenServiceOfferActive(sid, offerIndex)
  {
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

    if (service.purchases[msg.sender].expire == 0) {
      service.purchasesList.push(msg.sender);
    }
    service.purchases[msg.sender].expire = expire;
    emit ServicePurchased(sid, offerIndex, msg.sender, offer.price, offer.duration, expire);
  }

  /**
    External views
   */

  function servicesListLength()
    external view
    returns (uint length)
  {
    return servicesList.length;
  }

  function servicesVersionsListLength(bytes32 sid)
    external view
    whenServiceExist(sid)
    returns (uint length)
  {
    return services[sid].versionsList.length;
  }

  function servicesVersionsList(bytes32 sid, uint versionIndex)
    external view
    whenServiceExist(sid)
    returns (bytes32 hash)
  {
    return services[sid].versionsList[versionIndex];
  }

  function servicesVersion(bytes32 sid, bytes32 hash)
    external view
    whenServiceExist(sid)
    returns (bytes memory manifest, bytes memory manifestProtocol)
  {
    Version storage version = services[sid].versions[hash];
    return (version.manifest, version.manifestProtocol);
  }

  function servicesOffersLength(bytes32 sid)
    external view
    whenServiceExist(sid)
    returns (uint length)
  {
    return services[sid].offers.length;
  }

  function servicesOffer(bytes32 sid, uint offerIndex)
    external view
    whenServiceExist(sid)
    returns (uint price, uint duration, bool active)
  {
    Offer storage offer = services[sid].offers[offerIndex];
    return (offer.price, offer.duration, offer.active);
  }

  function servicesPurchasesListLength(bytes32 sid)
    external view
    whenServiceExist(sid)
    returns (uint length)
  {
    return services[sid].purchasesList.length;
  }

  function servicesPurchasesList(bytes32 sid, uint purchaseIndex)
    external view
    whenServiceExist(sid)
    returns (address purchaser)
  {
    return services[sid].purchasesList[purchaseIndex];
  }

  function servicesPurchases(bytes32 sid, address purchaser)
    external view
    whenServiceExist(sid)
    returns (uint expire)
  {
    return services[sid].purchases[purchaser].expire;
  }

  function isAuthorized(bytes32 sid)
    external view
    returns (bool authorized)
  {
    return services[sid].owner == msg.sender ||
      services[sid].purchases[msg.sender].expire >= now;
  }

  /**
    Internal pure
   */

  function isBytesZero(bytes memory b) internal pure returns (bool) {
    if (b.length == 0) {
      return true;
    }
    bytes memory zero = new bytes(b.length);
    return keccak256(b) == keccak256(zero);
  }
}
