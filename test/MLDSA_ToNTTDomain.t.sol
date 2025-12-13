// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// ВАЖЛИВО: шлях такий самий, як у твоїх існуючих тестах (MLDSA_Decode*.t.sol).
import {MLDSA65_PolyVec} from "../contracts/verifier/MLDSA65_Verifier_v2.sol";

contract MLDSA_ToNTTDomain_Test is Test {
    function test_toNTTDomain_reduces_positive_over_q() public {
        int32[256] memory a;
        a[0] = int32(8380417 + 5);

        uint256[256] memory r = MLDSA65_PolyVec._toNTTDomain(a);
        assertEq(r[0], 5);
    }

    function test_toNTTDomain_reduces_negative() public {
        int32[256] memory a;
        a[0] = -1;

        uint256[256] memory r = MLDSA65_PolyVec._toNTTDomain(a);
        assertEq(r[0], 8380416);
    }
}
