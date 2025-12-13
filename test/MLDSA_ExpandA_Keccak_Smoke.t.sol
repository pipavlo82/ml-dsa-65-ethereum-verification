// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_ExpandA_KeccakFIPS204.sol";

contract MLDSA_ExpandA_Keccak_Smoke_Test is Test {
    // Детермінований rho для тестів
    bytes32 constant RHO = hex"000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f";

    uint16 constant N = 256;
    int32 constant Q = 8380417;

    function test_expandA_poly_deterministic() public {
        int32[256] memory a0 = MLDSA65_ExpandA_KeccakFIPS204.expandA_poly(RHO, 0, 0);
        int32[256] memory a1 = MLDSA65_ExpandA_KeccakFIPS204.expandA_poly(RHO, 0, 0);

        for (uint256 i = 0; i < N; ++i) {
            assertEq(a0[i], a1[i], "coeff mismatch");
        }
    }

    function test_expandA_poly_separates_row_and_col() public {
        int32[256] memory a00 = MLDSA65_ExpandA_KeccakFIPS204.expandA_poly(RHO, 0, 0);
        int32[256] memory a10 = MLDSA65_ExpandA_KeccakFIPS204.expandA_poly(RHO, 1, 0);
        int32[256] memory a01 = MLDSA65_ExpandA_KeccakFIPS204.expandA_poly(RHO, 0, 1);

        bool diffRow = false;
        bool diffCol = false;

        for (uint256 i = 0; i < N; ++i) {
            if (a00[i] != a10[i]) {
                diffRow = true;
                break;
            }
        }
        for (uint256 i = 0; i < N; ++i) {
            if (a00[i] != a01[i]) {
                diffCol = true;
                break;
            }
        }

        assertTrue(diffRow, "changing row must change A[row][col]");
        assertTrue(diffCol, "changing col must change A[row][col]");
    }

    function test_expandA_poly_coeffs_in_range() public {
        int32[256] memory a = MLDSA65_ExpandA_KeccakFIPS204.expandA_poly(RHO, 0, 0);

        for (uint256 i = 0; i < N; ++i) {
            // Покладемося на те, що поточний прототип дає коефіцієнти в [0, Q)
            assertTrue(a[i] >= 0 && a[i] < Q, "coeff out of range");
        }
    }
}
