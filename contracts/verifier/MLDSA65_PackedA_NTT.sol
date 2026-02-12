// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Decode packed A in NTT domain.
/// Format: K*L polys, each poly = 256 uint32 big-endian (1024 bytes).
library MLDSA65_PackedA_NTT {
    error PackedA_OutOfBounds();

    uint256 internal constant POLY_BYTES = 1024; // 256*4

    function loadPolyU32BE(
        bytes calldata packed,
        uint256 polyIndex,
        uint256[256] memory out
    ) internal pure {
        unchecked {
            uint256 base = polyIndex * POLY_BYTES;
            if (packed.length < base + POLY_BYTES) revert PackedA_OutOfBounds();

            assembly ("memory-safe") {
                let outPtr := out
                let cdPtr := add(packed.offset, base)

                // i = 0..255 step 8 (32 bytes -> 8x uint32)
                for { let i := 0 } lt(i, 256) { i := add(i, 8) } {
                    let w := calldataload(cdPtr)

                    mstore(add(outPtr, shl(5, i)),         and(shr(224, w), 0xffffffff))
                    mstore(add(outPtr, shl(5, add(i, 1))), and(shr(192, w), 0xffffffff))
                    mstore(add(outPtr, shl(5, add(i, 2))), and(shr(160, w), 0xffffffff))
                    mstore(add(outPtr, shl(5, add(i, 3))), and(shr(128, w), 0xffffffff))
                    mstore(add(outPtr, shl(5, add(i, 4))), and(shr(96,  w), 0xffffffff))
                    mstore(add(outPtr, shl(5, add(i, 5))), and(shr(64,  w), 0xffffffff))
                    mstore(add(outPtr, shl(5, add(i, 6))), and(shr(32,  w), 0xffffffff))
                    mstore(add(outPtr, shl(5, add(i, 7))), and(w,            0xffffffff))

                    cdPtr := add(cdPtr, 32)
                }
            }
        }
    }
}
