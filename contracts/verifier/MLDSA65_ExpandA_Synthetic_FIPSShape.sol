// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MLDSA65_Verifier_v2.sol";

/// @title Synthetic ExpandA with FIPS-like matrix shape
/// @notice Детерміністична, мала за коефіцієнтами A(rho), яку ми використовуємо
///         для KAT-ів та експериментів.
/// @dev    Це НЕ справжня FIPS-204 ExpandA, лише «формо-сумісний» заповнювач.
///
///  - Input:  rho (bytes32 seed)
///  - Output: L × K матриця многочленів степеня N над Z_q,
///            представлена як масив PolyVecK[5] (L = 5 для ML-DSA-65).
///
/// Формула коефіцієнтів у повній матриці A[rowL][colK][i]:
///   r0   = uint8(uint256(rho) & 0xFF);
///   base = rowL * 100 + colK * 10 + i;
///   coeff = base + r0;    // завжди < Q, позитивні малі значення.
library MLDSA65_ExpandA_Synthetic_FIPSShape {
    using MLDSA65_Poly for int32[256];

    /// @notice Генерує повну матрицю A(rho) у time-domain.
    /// @return A Масив довжини L=5, де кожен елемент — PolyVecK (K поліно).
    ///         Індексування: A[rowL].polys[colK] відповідає A[rowL][colK].
    function expandA(bytes32 rho) internal pure returns (MLDSA65_PolyVec.PolyVecK[5] memory A) {
        // Беремо лише молодший байт rho як простий seed
        uint8 r0 = uint8(uint256(rho) & 0xFF);

        // A[rowL][colK][i], rowL ∈ [0,L), colK ∈ [0,K)
        for (uint256 rowL = 0; rowL < MLDSA65_PolyVec.L; ++rowL) {
            for (uint256 colK = 0; colK < MLDSA65_PolyVec.K; ++colK) {
                for (uint256 i = 0; i < MLDSA65_PolyVec.N; ++i) {
                    uint256 base = rowL * 100 + colK * 10 + i;
                    int32 coeff = int32(int256(base + r0));
                    A[rowL].polys[colK][i] = coeff;
                }
            }
        }

        return A;
    }

    /// @notice Повертає один поліном A[rowK][colL] у time-domain.
    /// @dev Зовнішній інтерфейс:
    ///      - row ∈ [0, K) — індекс по K (рядки, як у MatrixVec/Verifier);
    ///      - col ∈ [0, L) — індекс по L (стовпці).
    ///
    ///      Повна матриця зберігається як A[rowL][colK], тому
    ///      A[rowK][colL] = fullA[colL].polys[rowK].
    ///      Щоб уникнути побудови fullA у пам’яті, безпосередньо
    ///      використовуємо відповідну формулу з переставленими row/col:
    ///        rowL = colL, colK = rowK.
    function expandA_poly(bytes32 rho, uint8 row, uint8 col)
        internal
        pure
        returns (int32[256] memory a)
    {
        // Перевірка меж у «K×L»-семантиці викликів
        require(row < MLDSA65_PolyVec.K, "expandA_poly: row out of range");
        require(col < MLDSA65_PolyVec.L, "expandA_poly: col out of range");

        uint8 r0 = uint8(uint256(rho) & 0xFF);

        // Тут rowK = row, colL = col.
        // У повній матриці це відповідає:
        //   rowL = colL, colK = rowK
        // ⇒ base = rowL*100 + colK*10 + i = col*100 + row*10 + i.
        for (uint256 i = 0; i < MLDSA65_PolyVec.N; ++i) {
            uint256 base = uint256(col) * 100 + uint256(row) * 10 + i;
            int32 coeff = int32(int256(base + r0));
            a[i] = coeff;
        }

        return a;
    }
}
