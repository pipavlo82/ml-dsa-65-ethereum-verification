// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import { MLDSA65_ExpandA_KeccakFIPS204 } from "../contracts/verifier/MLDSA65_ExpandA_KeccakFIPS204.sol";
import { NTT_MLDSA_Real } from "../contracts/ntt/NTT_MLDSA_Real.sol";

contract ExpandA_NTT_GasMicro_Test is Test {
    uint256 internal constant Q = 8380417;

    // rho0 = 0x00..00
    bytes32 internal constant RHO0 = bytes32(0);

    // rho1 = 0x010203...1f00 (32 bytes)
    bytes32 internal constant RHO1 =
        hex"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f00";

    function _toNTTDomain_u(int32[256] memory a) internal pure returns (uint256[256] memory r) {
        int256 q = int256(uint256(Q));
        for (uint256 i = 0; i < 256; ++i) {
            int256 x = int256(a[i]);
            int256 m = x % q;
            if (m < 0) m += q;
            r[i] = uint256(m);
        }
    }

    function _bench(bytes32 rho, uint256 row, uint256 col, string memory tag) internal {
        uint256 g0 = gasleft();

        // 1) ExpandA poly in int32 domain
        int32[256] memory a_i32 = MLDSA65_ExpandA_KeccakFIPS204.expandA_poly(rho, row, col);

        uint256 g1 = gasleft();

        // 2) Convert to uint256 mod Q (NTT domain input)
        uint256[256] memory a_u = _toNTTDomain_u(a_i32);

        uint256 g2 = gasleft();

        // 3) NTT
        uint256[256] memory a_ntt = NTT_MLDSA_Real.ntt(a_u);

        uint256 g3 = gasleft();

        // Keep compiler honest (avoid dead-code elimination)
        assertLt(a_ntt[0], Q);

        uint256 gas_expandA = g0 - g1;
        uint256 gas_toNTT   = g1 - g2;
        uint256 gas_ntt     = g2 - g3;
        uint256 gas_total   = g0 - g3;

        emit log_string(tag);
        emit log_named_uint("  gas_expandA_poly", gas_expandA);
        emit log_named_uint("  gas_toNTTDomain_u", gas_toNTT);
        emit log_named_uint("  gas_ntt_single_poly", gas_ntt);
        emit log_named_uint("  gas_total_expandA+toNTT+ntt", gas_total);
    }

    function test_expandA_toNTT_ntt_gas_rho0_row0_col0() public {
        _bench(RHO0, 0, 0, "rho0 row0 col0");
    }

    function test_expandA_toNTT_ntt_gas_rho1_row0_col0() public {
        _bench(RHO1, 0, 0, "rho1 row0 col0");
    }
}
