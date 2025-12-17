// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NTT_MLDSA_Zetas} from "./NTT_MLDSA_Zetas.sol";

/// @title ML-DSA-65 NTT Core (Cooley–Tukey / Gentleman–Sande)
/// @notice NTT/INTT для q=8380417. Для множення використовуємо EVM mulmod (швидко),
///         для додавання/віднімання — умовну редукцію (дешево).
library NTT_MLDSA_Real {
    uint256 internal constant Q = 8380417;
    uint256 internal constant N = 256;

    // 256^{-1} mod Q = 8347681
    uint256 internal constant N_INV = 8347681;

    /// @notice Forward NTT (Cooley–Tukey, decimation-in-time)
    /// @dev Використовує zetas[i] з NTT_MLDSA_Zetas.getZeta(i), i=1..255
    function ntt(uint256[256] memory a) internal pure returns (uint256[256] memory) {
        unchecked {
            uint256 k = 1; // zetas[0] зарезервована
            for (uint256 len = 128; len > 0; len >>= 1) {
                for (uint256 start = 0; start < N; start += 2 * len) {
                    uint256 zeta = NTT_MLDSA_Zetas.getZeta(k++);
                    uint256 off = len << 5; // len * 32 bytes

                    for (uint256 j = start; j < start + len; j++) {
                        uint256 aj;
                        uint256 bj;
                        uint256 pj = j << 5;

                        assembly ("memory-safe") {
                            let base := a
                            let p := add(base, pj)
                            aj := mload(p)
                            bj := mload(add(p, off))
                        }

                        // t = zeta * bj mod q
                        uint256 t = mulmod(zeta, bj, Q);

                        // r0 = aj + t mod q (conditional reduction)
                        uint256 r0 = aj + t;
                        if (r0 >= Q) r0 -= Q;

                        // r1 = aj - t mod q (conditional add Q)
                        uint256 r1;
                        if (aj >= t) r1 = aj - t;
                        else r1 = aj + Q - t;

                        assembly ("memory-safe") {
                            let base := a
                            let p := add(base, pj)
                            mstore(p, r0)
                            mstore(add(p, off), r1)
                        }
                    }
                }
            }
            return a;
        }
    }

    /// @notice Inverse NTT (Gentleman–Sande, decimation-in-frequency)
    /// @dev Використовує ті самі zetas у зворотному порядку: 255..1
    function intt(uint256[256] memory a) internal pure returns (uint256[256] memory) {
        unchecked {
            uint256 k = 255;
            for (uint256 len = 1; len < N; len <<= 1) {
                for (uint256 start = 0; start < N; start += 2 * len) {
                    uint256 zeta = NTT_MLDSA_Zetas.getZeta(k--);
                    uint256 off = len << 5;

                    for (uint256 j = start; j < start + len; j++) {
                        uint256 aj;
                        uint256 ajl;
                        uint256 pj = j << 5;

                        assembly ("memory-safe") {
                            let base := a
                            let p := add(base, pj)
                            aj := mload(p)
                            ajl := mload(add(p, off))
                        }

                        // sum = aj + ajl mod q
                        uint256 sum = aj + ajl;
                        if (sum >= Q) sum -= Q;

                        // diff = aj - ajl mod q
                        uint256 diff;
                        if (aj >= ajl) diff = aj - ajl;
                        else diff = aj + Q - ajl;

                        // out = zeta * diff mod q
                        uint256 out = mulmod(zeta, diff, Q);

                        assembly ("memory-safe") {
                            let base := a
                            let p := add(base, pj)
                            mstore(p, sum)
                            mstore(add(p, off), out)
                        }
                    }
                }
            }

            // Multiply by N^{-1} mod Q
            for (uint256 i = 0; i < N; i++) {
                a[i] = mulmod(a[i], N_INV, Q);
            }

            return a;
        }
    }
}
