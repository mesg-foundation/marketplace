pragma solidity ^0.5.2;

import "openzeppelin-eth/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-eth/contracts/token/ERC721/IERC721.sol";

interface IShop {
  function approveOffer(address _seller, IERC721 _store, uint256 _item, uint256 _price, IERC20 _currency) external returns (bool);
  function approvePurchase(address _buyer, address _seller, IERC721 _store, uint256 _item, uint256 _price, IERC20 _currency) external returns (bool);
}
