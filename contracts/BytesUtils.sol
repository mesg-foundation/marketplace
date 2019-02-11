pragma solidity >=0.5.0 <0.6.0;

library BytesUtils {
  function isZero(bytes memory b) internal pure returns (bool) {
    if (b.length == 0) {
      return true;
    }
    bytes memory zero = new bytes(b.length);
    return keccak256(b) == keccak256(zero);
  }
}
