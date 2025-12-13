// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NTT_MLDSA_Zetas} from "./NTT_MLDSA_Zetas.sol";

/// @title ML-DSA-65 NTT Core (реальна Cooley–Tukey / Gentleman–Sande)
/// @notice Поки що окрема реалізація NTT/INTT для експериментів і тестів
library NTT_MLDSA_Real {
    uint256 internal constant Q = 8380417;
    uint256 internal constant N = 256;
    // 256^{-1} mod Q = 8347681 (згенеровано скриптом)
    uint256 internal constant N_INV = 8347681;

    // ==========================
    //  Local modular helpers
    // ==========================

    /// @dev x, y завжди в [0, Q); результат також в [0, Q)
    function _addModQ(uint256 x, uint256 y) private pure returns (uint256 r) {
        unchecked {
            r = x + y;
            if (r >= Q) r -= Q;
        }
    }

    /// @dev (x - y) mod Q без addmod
    function _subModQ(uint256 x, uint256 y) private pure returns (uint256 r) {
        unchecked {
            r = x + Q - y;
            if (r >= Q) r -= Q;
        }
    }

    /// @dev (x * y) mod Q.
    /// Варіант 1: простий * % Q (поки що цього достатньо).
    function _mulModQ(uint256 x, uint256 y) private pure returns (uint256 r) {
        unchecked {
            uint256 p = x * y; // x,y < Q → p < 2^46, overflow не можливий
            r = p % Q;
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

                    for (uint256 j = start; j < start + len; j++) {
                        uint256 aj = a[j];
                        uint256 t = _mulModQ(zeta, a[j + len]);

                        // a[j]     = aj + t (mod Q)
                        // a[j+len] = aj - t (mod Q)
                        a[j] = _addModQ(aj, t);
                        a[j + len] = _subModQ(aj, t);
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

                    for (uint256 j = start; j < start + len; j++) {
                        uint256 aj = a[j];
                        uint256 ajl = a[j + len];

                        // sum  = a[j] + a[j+len]
                        // diff = a[j] - a[j+len]
                        uint256 sum = _addModQ(aj, ajl);
                        uint256 diff = _subModQ(aj, ajl);

                        a[j] = sum;
                        a[j + len] = _mulModQ(zeta, diff);
                    }
                }
            }

            // Множимо на N^{-1} mod Q
            for (uint256 i = 0; i < N; i++) {
                a[i] = _mulModQ(a[i], N_INV);
            }

            return a;
        }
    }
}

