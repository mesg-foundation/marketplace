pragma solidity >=0.5.0 <0.6.0;

library DnsUtils {
  function isDomainName(bytes memory s) internal pure returns (bool) {
    byte last = ".";
    bool ok = false;
    uint partlen = 0;

    for (uint i = 0; i < s.length; i++) {
      byte c = s[i];
      if (c >= "a" && c <= "z" || c == "_") {
        ok = true;
        partlen++;
      } else if (c >= "0" && c <= "9") {
        partlen++;
      } else if (c == "-") {
        // byte before dash cannot be dot.
        if (last == ".") {
          return false;
        }
        partlen++;
      } else if (c == ".") {
        // byte before dot cannot be dot, dash.
        if (last == "." || last == "-") {
          return false;
        }
        if (partlen > 63 || partlen == 0) {
          return false;
        }
        partlen = 0;
      } else {
        return false;
      }
      last = c;
    }
    if (last == "-" || partlen > 63) {
      return false;
    }
    return ok;
  }
}
