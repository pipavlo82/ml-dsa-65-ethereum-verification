// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// KeccakPRNG із ZKNox (ETHDILITHIUM)
import "../zknox_keccak/ZKNox_KeccakPRNG.sol";

/// @title MLDSA65_ExpandA_KeccakFIPS204
/// @notice Keccak/XOF-based ExpandA backend for ML-DSA-65 (FIPS-204 shape).
/// @dev Rejection sampling: беремо 23-бітні значення і приймаємо тільки якщо < Q.
///      Матриця A має форму K×L (K=6 рядків, L=5 колонок): A[row][col][i].
library MLDSA65_ExpandA_KeccakFIPS204 {
    uint256 internal constant N = 256;
    uint256 internal constant K = 6;
    uint256 internal constant L = 5;
    uint32 internal constant Q = 8380417;

    /// @notice ExpandA для одного полінома A[row][col] через rejection sampling.
    /// @dev Seed: "MLDSA65-ExpandA" || rho || uint16(row) || uint16(col) (домен-сепарація).
    function expandA_poly(bytes32 rho, uint256 row, uint256 col)
        internal
        pure
        returns (int32[256] memory a)
    {
        // ВАЖЛИВО: row < K (6), col < L (5)
        require(row < K && col < L, "ExpandA: idx");

        bytes memory seedInput = abi.encodePacked("MLDSA65-ExpandA", rho, uint16(row), uint16(col));

        KeccakPRNG memory prng = initPRNG(seedInput);

        uint256 i = 0;
        while (i < N) {
            uint8 b0 = nextByte(prng);
            uint8 b1 = nextByte(prng);
            uint8 b2 = nextByte(prng);

            // 23-bit candidate (Dilithium-style)
            uint32 t = uint32(b0) | (uint32(b1) << 8) | (uint32(b2) << 16);
            t &= 0x7FFFFF;

            if (t < Q) {
                // зберігаємо в [0, Q-1]
                a[i] = int32(uint32(t));
                unchecked {
                    ++i;
                }
            }
        }
    }

    /// @notice ExpandA матриці A ∈ Z_q^{K×L×N}, row-major: A[row][col][i].
    function expandA_matrix(bytes32 rho) internal pure returns (int32[256][L][K] memory A) {
        for (uint256 row = 0; row < K; ++row) {
            for (uint256 col = 0; col < L; ++col) {
                A[row][col] = expandA_poly(rho, row, col);
            }
        }
    }
}
