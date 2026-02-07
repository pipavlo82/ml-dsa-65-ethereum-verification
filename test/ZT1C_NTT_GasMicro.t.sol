// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { NTT_MLDSA_Real } from "../contracts/ntt/NTT_MLDSA_Real.sol";

contract ZT1C_NTT_GasMicro_Test is Test {
    uint256 internal constant Q = 8380417;
    uint256 internal constant K = 6;
    uint256 internal constant L = 5;

    function _randI32Poly(uint256 seed) internal pure returns (int32[256] memory a) {
        unchecked {
            uint256 x = seed;
            for (uint256 i = 0; i < 256; ++i) {
                x ^= (x << 13);
                x ^= (x >> 7);
                x ^= (x << 17);

                // робимо і позитивні, і негативні значення навколо q
                uint256 r = x % (Q * 4);
                int256 v = int256(r) - int256(Q * 2); // ~[-2q, +2q)
                a[i] = int32(v);
            }
        }
    }

    function _toNTTDomainU(int32[256] memory a) internal pure returns (uint256[256] memory r) {
        unchecked {
            int64 q = int64(int256(Q));
            for (uint256 i = 0; i < 256; ++i) {
                int64 x = int64(a[i]);
                x %= q;
                if (x < 0) x += q;
                r[i] = uint256(uint64(x));
            }
        }
    }

    function test_gas_toNTT_and_NTT_for_z_t1_c() public {
        uint256 g0 = gasleft();

        // z: 5 polys
        for (uint256 j = 0; j < L; ++j) {
            int32[256] memory z_i32 = _randI32Poly(0x1000 + j);
            uint256[256] memory z_u = _toNTTDomainU(z_i32);
            NTT_MLDSA_Real.ntt(z_u);
        }

        // t1: 6 polys
        for (uint256 k = 0; k < K; ++k) {
            int32[256] memory t1_i32 = _randI32Poly(0x2000 + k);
            uint256[256] memory t1_u = _toNTTDomainU(t1_i32);
            NTT_MLDSA_Real.ntt(t1_u);
        }

        // c: 1 poly
        int32[256] memory c_i32 = _randI32Poly(0x3000);
        uint256[256] memory c_u = _toNTTDomainU(c_i32);
        NTT_MLDSA_Real.ntt(c_u);

        uint256 used = g0 - gasleft();
        emit log_named_uint("gas_toNTT+NTT(z[5]+t1[6]+c[1])", used);
    }
}
