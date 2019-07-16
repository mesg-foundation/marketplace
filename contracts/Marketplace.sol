pragma solidity ^0.5.2;

import "openzeppelin-eth/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-eth/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-eth/contracts/ownership/Ownable.sol";
import "openzeppelin-eth/contracts/lifecycle/Pausable.sol";
import "openzeppelin-eth/contracts/utils/Address.sol";
import "zos-lib/contracts/Initializable.sol";

import "./MarketplaceStorage.sol";

contract Marketplace is Initializable, Ownable, Pausable, MarketplaceStorage {
  using Address for address;

  function initialize(address _owner) public initializer {
    require(_owner != address(0), "owner required");
    Ownable.initialize(_owner);
    Pausable.initialize(_owner);
  }

  function createShop(address _items, address[] memory _currencies) public whenNotPaused {
    require(_items.isContract(), "items should be tge address of a contract");
    // TODO: check that the ERC721 has the right interface

    require(_currencies.length > 0, "need to accept at least one currency");
    IERC20[] memory currencies = new IERC20[](_currencies.length);
    for (uint8 i = 0; i < _currencies.length; i++) {
      address currency = _currencies[i];
      require(currency.isContract(), "currency should be the address of a contract");
      // TODO: check that the ERC20 has the right interface
      currencies[i] = IERC20(currency);
    }

    uint createdAt = block.timestamp;
    bytes32 shopId = keccak256(abi.encodePacked(IERC721(_items), createdAt));
    shopsById[shopId] = Shop({
      id: shopId,
      owner: msg.sender,
      items: IERC721(_items),
      currencies: currencies,
      open: true,
      createdAt: createdAt
    });
    emit ShopCreated(shopId, msg.sender, IERC721(_items), currencies, createdAt);
  }

  function closeShop(bytes32 shopId) public whenNotPaused {
    Shop memory shop = shopsById[shopId];
    require(shop.owner == msg.sender, "not allowed");
    shopsById[shopId].open = false;
    emit ShopClosed(shopId);
  }

  function createOffer(bytes32 shopId, uint256 itemId, uint256 price, address currency) public whenNotPaused {
    Shop memory shop = shopsById[shopId];
    require(shop.open, "shop is closed");
    address seller = shop.items.ownerOf(itemId);
    require(seller == msg.sender, "not allowed");
    // TODO: check currency in the list of currencies of the shop

    uint createdAt = block.timestamp;
    bytes32 offerId = keccak256(abi.encodePacked(shopId, itemId, price, IERC20(currency), createdAt));
    offersById[offerId] = Offer({
      id: offerId,
      shopId: shopId,
      itemId: itemId,
      seller: seller,
      price: price,
      currency: IERC20(currency),
      createdAt: createdAt,
      active: true
    });
    emit OfferCreated(offerId, shopId, itemId, seller, price, currency, createdAt);
  }

  function purchase(bytes32 offerId) public whenNotPaused {
    Offer memory offer = offersById[offerId];
    Shop memory shop = shopsById[offer.shopId];
    require(shop.open, "shop is closed");
    require(shop.items.ownerOf(offer.itemId) == offer.seller, "owner of asset changed");
    require(offer.currency.transferFrom(msg.sender, offer.seller, offer.price), "payment error");
    shop.items.transferFrom(offer.seller, msg.sender, offer.itemId);
    offersById[offerId].active = false;
  }
}
