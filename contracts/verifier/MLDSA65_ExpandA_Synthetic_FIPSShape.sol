// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MLDSA65_Verifier_v2.sol";

/// @title Synthetic ExpandA with FIPS-like matrix shape
/// @notice Deterministic, small-coefficient A(rho) used for KATs and experiments.
///         This is NOT a real FIPS-204 ExpandA, лише «формо-сумісний» заповнювач.
library MLDSA65_ExpandA_Synthetic_FIPSShape {
    /// @notice Synthetic ExpandA:
    ///  - Input: rho (bytes32 seed)
    ///  - Output: L × K matrix of degree-N polynomials over Z_q
    ///            represented як масив PolyVecK[5] (L = 5 для ML-DSA-65).
    ///
    /// Формула коефіцієнтів:
    ///   r0   = uint8(uint256(rho) & 0xFF);
    ///   base = row * 100 + col * 10 + i;
    ///   coeff = base + r0;  // завжди < Q, позитивні малі значення.
    function expandA(
        bytes32 rho
    )
        internal
        pure
        returns (MLDSA65_PolyVec.PolyVecK[5] memory A)
    {
        // Беремо лише молодший байт rho як простий seed
        uint8 r0 = uint8(uint256(rho) & 0xFF);

        // Проходимо по всіх рядках (L), стовпцях (K) і коефіцієнтах (N)
        for (uint256 row = 0; row < MLDSA65_PolyVec.L; ++row) {
            for (uint256 col = 0; col < MLDSA65_PolyVec.K; ++col) {
                for (uint256 i = 0; i < MLDSA65_PolyVec.N; ++i) {
                    uint256 base = row * 100 + col * 10 + i;
                    // base ≤ 4*100 + 5*10 + 255 = 705, r0 ≤ 255 → coeff ≤ 960 << Q
                    int32 coeff = int32(int256(base + r0));
                    A[row].polys[col][i] = coeff;
                }
            }
        }

        return A;
    }
}
