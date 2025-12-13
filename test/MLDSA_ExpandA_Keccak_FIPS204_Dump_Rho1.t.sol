// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {MLDSA65_ExpandA_KeccakFIPS204} from "../contracts/verifier/MLDSA65_ExpandA_KeccakFIPS204.sol";

contract MLDSA_ExpandA_Keccak_FIPS204_Dump_Rho1 is Test {
    // Ненульовий rho у форматі bytes32 через hex"" – так компілятор не біситься
    bytes32 internal constant RHO1 = hex"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f";

    function test_dump_rho1_row0_col0_first256() public {
        int32[256] memory poly = MLDSA65_ExpandA_KeccakFIPS204.expandA_poly(RHO1, 0, 0);

        // Логимо просто значення коефіцієнтів по порядку – один int на рядок
        for (uint256 i = 0; i < 256; ++i) {
            console2.logInt(int256(poly[i]));
        }
    }
}
