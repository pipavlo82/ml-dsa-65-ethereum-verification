// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_Challenge.sol";

contract MLDSA_FIPSChallenge_Test is Test {
    function _countNonZero(int32[256] memory c) internal pure returns (uint256 nz) {
        for (uint256 i = 0; i < 256; ++i) {
            if (c[i] != 0) {
                ++nz;
            }
        }
    }

    function test_challenge_has_60_nonzero() public {
        bytes32 seed = bytes32(uint256(123));
        int32[256] memory c = MLDSA65_Challenge.polyChallenge(seed);

        uint256 nz = _countNonZero(c);
        assertEq(nz, 60, "challenge must have exactly 60 non-zero coeffs");
    }

    function test_challenge_coeffs_in_minus_one_plus_one() public {
        bytes32 seed = keccak256("test_challenge_coeffs_range");
        int32[256] memory c = MLDSA65_Challenge.polyChallenge(seed);

        for (uint256 i = 0; i < 256; ++i) {
            int32 v = c[i];
            if (v == 0) continue;
            assertTrue(v == 1 || v == -1, "non-zero coeff must be +1 or -1");
        }
    }

    function test_challenge_deterministic() public {
        bytes32 seed = keccak256("deterministic-seed");
        int32[256] memory c1 = MLDSA65_Challenge.polyChallenge(seed);
        int32[256] memory c2 = MLDSA65_Challenge.polyChallenge(seed);

        for (uint256 i = 0; i < 256; ++i) {
            assertEq(c1[i], c2[i], "same seed must give same polynomial");
        }
    }

    function test_challenge_differs_for_different_seeds() public {
        bytes32 seed1 = keccak256("seed-1");
        bytes32 seed2 = keccak256("seed-2");
        int32[256] memory c1 = MLDSA65_Challenge.polyChallenge(seed1);
        int32[256] memory c2 = MLDSA65_Challenge.polyChallenge(seed2);

        uint256 equal = 0;
        for (uint256 i = 0; i < 256; ++i) {
            if (c1[i] == c2[i]) {
                ++equal;
            }
        }

        // Дуже м’яка перевірка: просто вимагаємо, щоб полінони не співпали 1:1.
        assertLt(equal, 256, "polynomials for different seeds should not match exactly");
    }
}
