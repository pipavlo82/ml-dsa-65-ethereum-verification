// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_Challenge.sol";

contract MLDSA_Challenge_Test is Test {
    using MLDSA65_Challenge for bytes32;

    function test_challenge_coeff_range() public {
        bytes32 digest = keccak256("test-digest");
        int8[256] memory c = MLDSA65_Challenge.deriveChallenge(digest);

        for (uint256 i = 0; i < 256; ++i) {
            int256 v = int256(int8(c[i]));
            assertTrue(v >= -1 && v <= 1, "coeff out of {-1,0,1}");
        }
    }

    function test_challenge_deterministic() public {
        bytes32 digest = keccak256("same-input");
        int8[256] memory c1 = MLDSA65_Challenge.deriveChallenge(digest);
        int8[256] memory c2 = MLDSA65_Challenge.deriveChallenge(digest);

        for (uint256 i = 0; i < 256; ++i) {
            assertEq(c1[i], c2[i], "non-deterministic coeff");
        }
    }

    function test_challenge_changes_with_input() public {
        bytes32 d1 = keccak256("input-1");
        bytes32 d2 = keccak256("input-2");

        int8[256] memory c1 = MLDSA65_Challenge.deriveChallenge(d1);
        int8[256] memory c2 = MLDSA65_Challenge.deriveChallenge(d2);

        // Перевіряємо, що не всі коефіцієнти збігаються
        bool anyDiff = false;
        for (uint256 i = 0; i < 256; ++i) {
            if (c1[i] != c2[i]) {
                anyDiff = true;
                break;
            }
        }
        assertTrue(anyDiff, "challenge should differ for different inputs");
    }
}
