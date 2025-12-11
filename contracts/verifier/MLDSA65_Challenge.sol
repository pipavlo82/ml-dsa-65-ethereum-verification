// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice FIPS-204 style challenge polynomial generator for ML-DSA-65.
/// @dev 256 coefficients, exactly 60 non-zero entries in {-1, +1}.
library MLDSA65_Challenge {
    uint256 internal constant N = 256;
    uint256 internal constant NONZERO = 60;

    /// @notice Derive a challenge polynomial c(x) from a 32-byte seed.
    /// @dev Shape-compatible with ML-DSA/Dilithium: exactly 60 non-zero coefficients in {-1, +1}.
    ///      Uses keccak256 as an EVM-friendly XOF stand-in for SHAKE256.
    function polyChallenge(bytes32 seed) internal pure returns (int32[256] memory c) {
        // Use lower 64 bits of seed as initial sign bits.
        uint64 signs = uint64(uint256(seed));

        uint256 filled = 0;
        uint256 nonce = 0;

        while (filled < NONZERO) {
            // Derive a new 32-byte block of randomness from (seed, nonce).
            bytes32 block_ = keccak256(abi.encodePacked(seed, nonce));
            unchecked {
                ++nonce;
            }

            // Consume bytes of the block as candidate positions in [0, 255].
            for (uint256 i = 0; i < 32 && filled < NONZERO; ++i) {
                uint8 b = uint8(block_[i]);
                uint8 idx = b; // 0..255

                // Skip if this position is already non-zero.
                if (c[idx] != 0) {
                    continue;
                }

                // Take next sign bit; if we run out, refill from a fresh block.
                int32 sign = (signs & 1) == 1 ? int32(1) : int32(-1);
                signs >>= 1;
                if (signs == 0) {
                    signs = uint64(
                        uint256(keccak256(abi.encodePacked(seed, nonce)))
                    );
                    unchecked {
                        ++nonce;
                    }
                }

                c[idx] = sign;
                unchecked {
                    ++filled;
                }
            }
        }
    }
}
