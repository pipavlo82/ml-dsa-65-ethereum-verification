// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Synthetic ExpandA helper for ML-DSA-65 on Ethereum.
/// @dev This is a keccak256-based test PRF, **not** the real FIPS-204 SHAKE128 ExpandA.
///      It matches the previous `_expandA_poly` implementation from MLDSA65_Verifier_v2.
library MLDSA65_ExpandA {
    int32 internal constant Q = 8380417;
    uint256 internal constant N = 256;

    /// @notice Synthetic A[row][col] polynomial in the time domain.
    /// @dev Uses keccak256(rho || row || col || i) and reduces 24 bits mod Q.
    function expandA_poly(
        bytes32 rho,
        uint8 row,
        uint8 col
    ) internal pure returns (int32[256] memory a) {
        uint32 q = uint32(uint32(uint256(int256(Q))));
        for (uint256 i = 0; i < N; ++i) {
            // keccak256(rho || row || col || i)
            bytes32 h = keccak256(
                abi.encodePacked(rho, row, col, uint16(i))
            );

            // Take 24 bits from h[0..2] and reduce mod q
            uint32 v24 =
                uint32(uint8(h[0])) |
                (uint32(uint8(h[1])) << 8) |
                (uint32(uint8(h[2])) << 16);

            uint32 reduced = v24 % q;
            a[i] = int32(int256(uint256(reduced)));
        }
    }
}
