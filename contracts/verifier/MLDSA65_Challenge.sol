// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MLDSA65_Challenge
/// @notice Placeholder challenge polynomial constructor for ML-DSA-65.
/// @dev This is NOT the real FIPS-204 SHAKE256-based poly_challenge.
///      It uses keccak256 as a stand-in, but matches the *shape*:
///      c is a polynomial with coefficients in {-1, 0, 1}.
library MLDSA65_Challenge {
    uint256 internal constant N = 256;

    /// @notice Derive a synthetic challenge polynomial c ∈ {-1,0,1}^256
    /// @dev Input is a 32-byte digest (e.g. message hash or rho || t1 || z hash).
    ///      Implementation:
    ///        - For each i, take keccak256(digest || i)
    ///        - Use low 2 bits to choose {-1, 0, 1} with slight bias
    ///      This is intentionally simple and deterministic for testing.
    function deriveChallenge(
        bytes32 digest
    ) internal pure returns (int8[256] memory c) {
        for (uint256 i = 0; i < N; ++i) {
            // domain separation by index
            bytes32 blockHash = keccak256(abi.encodePacked(digest, uint16(i)));

            // take the lowest 2 bits
            uint8 v = uint8(uint256(blockHash) & 0x03);

            // map {0,1,2,3} -> {0, 1, -1, 0}
            int8 coeff;
            if (v == 0) {
                coeff = 0;
            } else if (v == 1) {
                coeff = 1;
            } else if (v == 2) {
                coeff = -1;
            } else {
                coeff = 0;
            }

            c[i] = coeff;
        }
    }
}
