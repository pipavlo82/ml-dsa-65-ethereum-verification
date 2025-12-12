// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_ExpandA_KeccakFIPS204.sol";

contract MLDSA_ExpandA_Keccak_Matrix_Smoke_Test is Test {
    uint256 constant N = 256;
    uint256 constant K = 6;
    uint256 constant L = 5;

    function test_expandA_matrix_deterministic() public {
        bytes32 rho = keccak256("expandA-matrix-deterministic");

        int32[256][K][L] memory A1 =
            MLDSA65_ExpandA_KeccakFIPS204.expandA_matrix(rho);
        int32[256][K][L] memory A2 =
            MLDSA65_ExpandA_KeccakFIPS204.expandA_matrix(rho);

        // Перевіряємо невелику підмножину, щоб не робити тест занадто важким
        for (uint256 row = 0; row < L; ++row) {
            for (uint256 col = 0; col < K; ++col) {
                for (uint256 i = 0; i < 8; ++i) {
                    assertEq(
                        A1[row][col][i],
                        A2[row][col][i],
                        "matrix not deterministic"
                    );
                }
            }
        }
    }

    function test_expandA_matrix_separates_row_and_col() public {
        bytes32 rho = keccak256("expandA-matrix-separation");

        int32[256][K][L] memory A =
            MLDSA65_ExpandA_KeccakFIPS204.expandA_matrix(rho);

        // Беремо дві різні позиції (row,col) і очікуємо відмінність
        uint256 row0 = 0;
        uint256 col0 = 0;
        uint256 row1 = 1;
        uint256 col1 = 2;

        bool diff = false;
        for (uint256 i = 0; i < 16; ++i) {
            if (A[row0][col0][i] != A[row1][col1][i]) {
                diff = true;
                break;
            }
        }

        assertTrue(diff, "row/col separation failed");
    }
}
