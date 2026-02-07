// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_Challenge.sol";

contract MLDSA_FIPSChallenge_Test is Test {
    function test_challenge_has_60_nonzero() public {
        bytes32 seed = keccak256("seed-1");
        int32[256] memory c = MLDSA65_Challenge.poly_challenge(seed);

        uint256 nonzero;
        for (uint256 i = 0; i < 256; ++i) {
            if (c[i] != 0) nonzero++;
        }
        assertEq(nonzero, 60, "must have exactly 60 nonzero coeffs");
    }

    function test_challenge_coeffs_in_minus_one_plus_one() public {
        bytes32 seed = keccak256("seed-1");
        int32[256] memory c = MLDSA65_Challenge.poly_challenge(seed);

        for (uint256 i = 0; i < 256; ++i) {
            int32 v = c[i];
            assertTrue(v >= -1 && v <= 1, "coeff must be in [-1,1]");
        }
    }

    function test_challenge_deterministic() public {
        bytes32 seed = keccak256("seed-123");
        int32[256] memory c1 = MLDSA65_Challenge.poly_challenge(seed);
        int32[256] memory c2 = MLDSA65_Challenge.poly_challenge(seed);

        for (uint256 i = 0; i < 256; ++i) {
            assertEq(c1[i], c2[i], "deterministic per seed");
        }
    }

    function test_challenge_differs_for_different_seeds() public {
        bytes32 seed1 = keccak256("seed-A");
        bytes32 seed2 = keccak256("seed-B");
        int32[256] memory c1 = MLDSA65_Challenge.poly_challenge(seed1);
        int32[256] memory c2 = MLDSA65_Challenge.poly_challenge(seed2);

        uint256 diff;
        for (uint256 i = 0; i < 256; ++i) {
            if (c1[i] != c2[i]) diff++;
        }
        assertGt(diff, 0, "different seeds should produce different polys");
    }
}
