// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MLDSA65_ExpandA_KeccakFIPS204} from "../contracts/verifier/MLDSA65_ExpandA_KeccakFIPS204.sol";

contract ExpandA_GasMicro_Test is Test {
    bytes32 constant RHO0 = bytes32(0);
    bytes32 constant RHO1 =
        hex"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f00";

    function _touch(int32[256] memory a) internal pure returns (int256 s) {
        // “touch” кілька коефіцієнтів, щоб оптимізатор не викинув результат
        for (uint256 i = 0; i < 8; ++i) s += a[i];
    }

    function test_expandA_poly_gas_rho0_row0_col0() public {
        uint256 g0 = gasleft();
        int32[256] memory a = MLDSA65_ExpandA_KeccakFIPS204.expandA_poly(RHO0, 0, 0);
        uint256 used = g0 - gasleft();
        emit log_named_uint("expandA_poly gas (rho0, row0 col0)", used);
        assertTrue(_touch(a) != type(int256).min);
    }

    function test_expandA_poly_gas_rho1_row0_col0() public {
        uint256 g0 = gasleft();
        int32[256] memory a = MLDSA65_ExpandA_KeccakFIPS204.expandA_poly(RHO1, 0, 0);
        uint256 used = g0 - gasleft();
        emit log_named_uint("expandA_poly gas (rho1, row0 col0)", used);
        assertTrue(_touch(a) != type(int256).min);
    }

    function test_expandA_matrix_6x5_polys_gas_rho0() public {
        uint256 g0 = gasleft();
        int256 sum;

        // K=6, L=5
        for (uint256 row = 0; row < 6; ++row) {
            for (uint256 col = 0; col < 5; ++col) {
                int32[256] memory a = MLDSA65_ExpandA_KeccakFIPS204.expandA_poly(RHO0, row, col);
                sum += a[0];
            }
        }

        uint256 used = g0 - gasleft();
        emit log_named_uint("expandA_matrix 6x5 polys gas (rho0)", used);
        assertTrue(sum != type(int256).min);
    }
}
