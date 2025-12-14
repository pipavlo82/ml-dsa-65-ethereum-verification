// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NTT_MLDSA_Zetas} from "./NTT_MLDSA_Zetas.sol";

/// @title ML-DSA-65 NTT Core (реальна Cooley–Tukey / Gentleman–Sande)
/// @notice Оптимізована реалізація NTT/INTT з Barrett reduction
library NTT_MLDSA_Real {
    uint256 internal constant Q = 8380417;
    uint256 internal constant N = 256;
    
    // 256^{-1} mod Q = 8347681 (згенеровано скриптом)
    uint256 internal constant N_INV = 8347681;
    
    // Barrett reduction constant: mu = floor(2^64 / Q)
    uint256 internal constant MU64 = 2201172575745;

    // ==========================
    //  Optimized modular helpers
    // ==========================

    /// @dev Fast addition mod Q for a, b in [0, Q)
    function _addQ(uint256 a, uint256 b) internal pure returns (uint256 r) {
        unchecked {
            r = a + b;
            if (r >= Q) r -= Q;
        }
    }

    /// @dev Fast subtraction mod Q for a, b in [0, Q)
    function _subQ(uint256 a, uint256 b) internal pure returns (uint256 r) {
        unchecked {
            // assume a, b in [0, Q)
            if (a >= b) r = a - b;
            else r = a + Q - b;
        }
    }

    /// @dev Barrett reduction for x < ~2^64 (in practice x ~< 2^50 for our use case)
    function _mulQ(uint256 a, uint256 b) internal pure returns (uint256 r) {
        unchecked {
            uint256 x = a * b;                   // safe: a, b ~< 2Q
            uint256 qhat = (x * MU64) >> 64;     // ~ floor(x / Q)
            r = x - qhat * Q;
            if (r >= Q) r -= Q;
            if (r >= Q) r -= Q;                  // sometimes need 2 corrections
        }
    }

    /// @notice Forward NTT (Cooley–Tukey, decimation-in-time)
    /// @dev Використовує zetas[i] з NTT_MLDSA_Zetas.getZeta(i)
    function ntt(uint256[256] memory a) internal pure returns (uint256[256] memory) {
        unchecked {
            // Як у Dilithium: zetas[0] зарезервована, починаємо з 1
            uint256 k = 1;
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

                        uint256 t = _mulQ(zeta, bj);

                        uint256 r0;
                        uint256 r1;

                        r0 = aj + t;
                        if (r0 >= Q) r0 -= Q;

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
    /// @dev Використовує ті самі zetas у зворотному порядку
    function intt(uint256[256] memory a) internal pure returns (uint256[256] memory) {
        unchecked {
            // Як у Dilithium: йдемо від zetas[255] до zetas[1]
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

                        uint256 sum;
                        uint256 diff;

                        sum = aj + ajl;
                        if (sum >= Q) sum -= Q;

                        if (aj >= ajl) diff = aj - ajl;
                        else diff = aj + Q - ajl;

                        uint256 out = _mulQ(zeta, diff);

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
                uint256 ai = a[i];
                a[i] = _mulQ(ai, N_INV);
            }
            
            return a;
        }
    }
}
