pragma solidity ^0.5.2;

import "openzeppelin-eth/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-eth/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-eth/contracts/utils/Address.sol";
import "zos-lib/contracts/Initializable.sol";

import "./IShop.sol";

contract DirectOffer is Initializable {
  using Address for address;

  struct Offer {
    bytes32 id;
    IShop shop;
    IERC721 store;
    uint256 item;
    address seller;
    address buyer;
    uint256 price;
    IERC20 currency;
    uint createdAt;
    bool active;
  }

  mapping(bytes32 => Offer) public offersById;

  event OfferCreated(bytes32 offerId, IShop shop, IERC721 store, uint256 item, address seller, uint256 price, IERC20 currency, uint createdAt);
  event OfferPurchased(bytes32 offerId, address buyer, IShop shop, IERC721 store, uint256 item, address seller, uint256 price, IERC20 currency, uint createdAt);

  function initialize() public initializer {}

  function create(address _shop, address _store, uint256 _item, uint256 _price, address _currency) public {
    require(_shop.isContract(), "shop should be the address of a IShop contract");
    // TODO: check that contracts implement the right interface

    IShop shop = IShop(_shop);
    require(shop.approveOffer(msg.sender, IERC721(_store), _item, _price, IERC20(_currency)), "not approved by the shop");

    uint createdAt = block.timestamp;
    bytes32 offerId = keccak256(abi.encodePacked(shop, IERC721(_store), _item, _price, IERC20(_currency), createdAt));
    offersById[offerId] = Offer({
      id: offerId,
      shop: shop,
      store: IERC721(_store),
      item: _item,
      seller: msg.sender,
      buyer: address(0),
      price: _price,
      currency: IERC20(_currency),
      createdAt: createdAt,
      active: true
    });
    emit OfferCreated(offerId, shop, IERC721(_store), _item, msg.sender, _price, IERC20(_currency), createdAt);
  }

  function purchase(bytes32 _offer) public {
    Offer storage offer = offersById[_offer];
    IShop shop = offer.shop;
    require(offer.active, "offer is not active anymore");
    require(shop.approvePurchase(msg.sender, offer.seller, offer.store, offer.item, offer.price, offer.currency), "not approved by the shop");
    require(offer.currency.transferFrom(msg.sender, offer.seller, offer.price), "payment error");
    offer.store.transferFrom(offer.seller, msg.sender, offer.item);
    offer.buyer = msg.sender;
    offer.active = false;
    emit OfferPurchased(offer.id, offer.buyer, offer.shop, offer.store, offer.item, offer.seller, offer.price, offer.currency, offer.createdAt);
  }
}
