// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library MontgomeryMLDSA {
    // ML-DSA-65 modulus and Montgomery parameters (R = 2^32)
    uint256 constant Q = 8380417; // modulus
    uint256 constant Q_INV = 4236238847; // inverse of -Q modulo 2^32
    uint256 constant R2 = 2365951; // 2^64 mod Q (Montgomery square)

    uint256 constant MASK32 = 0xFFFFFFFF;
    uint256 constant MASK64 = 0xFFFFFFFFFFFFFFFF;

    /// ----------------------------------------------------------------------
    /// Low-level Montgomery reduction (matches Dilithium / BoringSSL pattern)
    /// ----------------------------------------------------------------------
    /// Input:  x < 2^64 (ми це гарантуємо у викликах)
    /// Output: x * R^{-1} mod Q, в інтервалі [0, Q)
    function montgomeryReduce(uint256 x) internal pure returns (uint256) {
        unchecked {
            // Емітуємо 64-бітний тип
            x &= MASK64;

            // a = (uint32_t)x * Q_INV  (молодші 32 біти, результат теж 32 біти)
            uint256 a = (x & MASK32) * Q_INV;
            a &= MASK32;

            // b = x + a * Q  (ще завжди < 2^64 у нашому діапазоні)
            uint256 b = x + a * Q;
            b &= MASK64;

            // c = b >> 32
            uint256 c = b >> 32;

            // reduce_once(c): якщо c >= Q, віднімаємо Q
            if (c >= Q) {
                c -= Q;
            }
            return c;
        }
    }

    /// ----------------------------------------------------------------------
    /// High-level Montgomery operations
    /// ----------------------------------------------------------------------

    /// @dev Montgomery multiplication: (a * b * R^{-1}) mod Q
    ///      При a,b < Q це просто звичайне множення в полі, але в Montgomery-домені.
    function montgomeryMul(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            // a,b < Q < 2^23 → a*b < 2^46 → точно влізає в 64 біти
            uint256 x = a * b;
            return montgomeryReduce(x);
        }
    }

    /// @dev Перевід у Montgomery-домен: x * R mod Q.
    ///      Реалізовано як montgomeryReduce(x * R2), де R2 = 2^64 mod Q.
    function toMontgomery(uint256 x) internal pure returns (uint256) {
        unchecked {
            // x < Q, R2 < Q → x * R2 < 2^46, теж в межах 64 біт
            uint256 t = x * R2;
            return montgomeryReduce(t);
        }
    }

    /// @dev Вихід з Montgomery-домену: x / R mod Q.
    ///      Реалізовано як ще один montgomeryReduce.
    function fromMontgomery(uint256 x) internal pure returns (uint256) {
        return montgomeryReduce(x);
    }
}
