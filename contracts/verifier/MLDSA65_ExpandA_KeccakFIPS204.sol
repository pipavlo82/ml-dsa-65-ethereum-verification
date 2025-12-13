// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Працюємо безпосередньо з KeccakPRNG із ZKNox (ETHDILITHIUM)
import "../zknox_keccak/ZKNox_KeccakPRNG.sol";

/// @title MLDSA65_ExpandA_KeccakFIPS204
/// @notice Keccak/SHAKE-based ExpandA backend for ML-DSA-65 (FIPS-204 shape).
/// @dev Використовує KeccakPRNG як XOF для (rho, row, col).
library MLDSA65_ExpandA_KeccakFIPS204 {
    uint256 internal constant N = 256;
    uint256 internal constant K = 6;
    uint256 internal constant L = 5;
    int32 internal constant Q = 8380417;

    /// @notice Keccak-based ExpandA для одного полінома A[row][col].
    /// @dev Поки що: простий мод-q + центроване представлення (плейсхолдер замість точного FIPS-семплінгу).
    function expandA_poly(
        bytes32 rho,
        uint256 row,
        uint256 col
    ) internal pure returns (int32[256] memory a) {
        // Домен-сепарація: (rho, row, col)
        bytes memory seedInput = abi.encodePacked(rho, uint8(row), uint8(col));
        KeccakPRNG memory prng = initPRNG(seedInput);

        for (uint256 i = 0; i < N; ++i) {
            // 16-бітове слово з двох байтів XOF
            uint8 b0 = nextByte(prng);
            uint8 b1 = nextByte(prng);
            uint16 v = uint16(b0) | (uint16(b1) << 8);

            // [0, Q-1]
            int32 c = int32(uint32(v) % uint32(uint32(Q)));

            // Центрована форма в ~[-Q/2, Q/2]
            if (c > Q / 2) {
                c -= Q;
            }
            a[i] = c;
        }
    }

    /// @notice Keccak-based ExpandA матриці A ∈ Z_q^{L×K×N}, row-major: A[row][col][i].
    function expandA_matrix(bytes32 rho)
        internal
        pure
        returns (int32[256][K][L] memory A)
    {
        for (uint256 row = 0; row < L; ++row) {
            for (uint256 col = 0; col < K; ++col) {
                A[row][col] = expandA_poly(rho, row, col);
            }
        }
    }
}
