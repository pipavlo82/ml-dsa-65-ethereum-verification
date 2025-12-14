// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_Challenge.sol";

contract MLDSA_Challenge_Test is Test {
    function test_poly_challenge_basic_shape() public {
        bytes32 seed = keccak256("test-seed");
        int32[256] memory c = MLDSA65_Challenge.poly_challenge(seed);

        uint256 nonzero;
        for (uint256 i = 0; i < 256; ++i) {
            int32 v = c[i];
            // всі коефіцієнти в [-1, 1]
            assertTrue(v >= -1 && v <= 1, "coeff must be -1, 0 or 1");
            if (v != 0) nonzero++;
        }

        // рівно 60 ненульових
        assertEq(nonzero, 60, "must have exactly 60 nonzero coeffs");
    }

    function test_deriveChallenge_matches_poly_challenge() public {
        bytes32 seed = keccak256("another-seed");
        int32[256] memory c32 = MLDSA65_Challenge.poly_challenge(seed);
        int8[256] memory c8 = MLDSA65_Challenge.deriveChallenge(seed);

        for (uint256 i = 0; i < 256; ++i) {
            assertEq(int8(c32[i]), c8[i], "int8/int32 views must match");
        }
    }
}
