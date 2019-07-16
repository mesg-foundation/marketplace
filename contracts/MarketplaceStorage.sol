pragma solidity ^0.5.2;

import "openzeppelin-eth/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-eth/contracts/token/ERC721/IERC721.sol";

contract MarketplaceStorage {
  struct Shop {
    address owner;
    bytes32 id;
    IERC721 items;
    IERC20[] currencies;
    bool open;
    uint createdAt;
  }

  struct Offer {
    bytes32 id;
    bytes32 shopId;
    uint256 itemId;
    address seller;
    uint256 price;
    IERC20 currency;
    uint createdAt;
    bool active;
  }

  mapping(bytes32 => Shop) public shopsById;
  mapping(bytes32 => Offer) public offersById;

  event ShopCreated(
    bytes32 id,
    address indexed owner,
    IERC721 indexed items,
    IERC20[] currencies,
    uint createdAt
  );
  event ShopClosed(bytes32 id);

  event OfferCreated(
    bytes32 id,
    bytes32 indexed shopId,
    uint256 indexed itemId,
    address seller,
    uint256 price,
    address currency,
    uint createdAt
  );
}
