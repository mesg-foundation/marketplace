pragma solidity ^0.5.2;

import "openzeppelin-eth/contracts/ownership/Ownable.sol";
import "openzeppelin-eth/contracts/lifecycle/Pausable.sol";
import "zos-lib/contracts/Initializable.sol";

import "./IShop.sol";

contract Shop is Initializable, Ownable, Pausable, IShop {

  function approveOffer(address _seller, IERC721, uint256, uint256 _price, IERC20) external returns (bool) {
    // TODO: check that the store and the currency are implementing the right interface
    require(_seller != address(0), "invalid address");
    require(_price > 0, "price should be greater than 0");
    return true;
  }

  function approvePurchase(address _buyer, address _seller, IERC721 _store, uint256 _item, uint256 _price, IERC20 _currency) external returns (bool) {
    require(_store.ownerOf(_item) == _seller, "owner of asset changed");
    require(_currency.balanceOf(_buyer) >= _price, "not enough token");
    return true;
  }

  function initialize(address owner) public initializer {
    require(owner != address(0), "owner required");
    Ownable.initialize(owner);
    Pausable.initialize(owner);
  }

}
