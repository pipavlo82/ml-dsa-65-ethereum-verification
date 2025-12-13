// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_Verifier_v2.sol";

/// @notice Harness to expose internal decode helpers from MLDSA65_Verifier_v2.
contract MLDSA_FIPSPack_t1_Harness is MLDSA65_Verifier_v2 {
    function exposedDecodePublicKey(bytes memory raw) external pure returns (DecodedPublicKey memory) {
        PublicKey memory pk = PublicKey({raw: raw});
        return _decodePublicKey(pk);
    }
}

/// @notice Tests FIPS-204 10-bit packing for t1 (first 4 coeffs + full poly).
contract MLDSA_FIPSPack_t1_Test is Test {
    MLDSA_FIPSPack_t1_Harness internal harness;

    function setUp() public {
        harness = new MLDSA_FIPSPack_t1_Harness();
    }

    /// @dev Packs 4×10-bit coefficients into 5 bytes according to Dilithium/ML-DSA layout:
    ///      t0 = (b0 | (b1 << 8)) & 0x3FF
    ///      t1 = ((b1 >> 2) | (b2 << 6)) & 0x3FF
    ///      t2 = ((b2 >> 4) | (b3 << 4)) & 0x3FF
    ///      t3 = ((b3 >> 6) | (b4 << 2)) & 0x3FF
    function _pack4x10(uint16 t0, uint16 t1_, uint16 t2, uint16 t3) internal pure returns (bytes5 outBytes) {
        // Ensure inputs are 10-bit.
        require(t0 < 1024 && t1_ < 1024 && t2 < 1024 && t3 < 1024, "coeff out of range");

        // Стандартне 4×10 → 40 біт: [t0 | t1<<10 | t2<<20 | t3<<30]
        uint64 acc = uint64(t0) | (uint64(t1_) << 10) | (uint64(t2) << 20) | (uint64(t3) << 30);

        bytes memory tmp = new bytes(5);
        tmp[0] = bytes1(uint8(acc & 0xFF));
        tmp[1] = bytes1(uint8((acc >> 8) & 0xFF));
        tmp[2] = bytes1(uint8((acc >> 16) & 0xFF));
        tmp[3] = bytes1(uint8((acc >> 24) & 0xFF));
        tmp[4] = bytes1(uint8((acc >> 32) & 0xFF));

        assembly {
            outBytes := mload(add(tmp, 0x20))
        }
    }

    /// @dev Helper: пакує повний поліном (256×10 біт) у 320 байтів FIPS-204 layout.
    function _packPoly10(uint16[256] memory coeffs) internal pure returns (bytes memory outBytes) {
        bytes memory packed = new bytes(320);
        uint256 byteOffset = 0;

        for (uint256 group = 0; group < 64; ++group) {
            uint256 baseIdx = group * 4;

            uint16 c0 = coeffs[baseIdx + 0];
            uint16 c1 = coeffs[baseIdx + 1];
            uint16 c2 = coeffs[baseIdx + 2];
            uint16 c3 = coeffs[baseIdx + 3];

            bytes5 chunk = _pack4x10(c0, c1, c2, c3);

            for (uint256 j = 0; j < 5; ++j) {
                packed[byteOffset + j] = chunk[j];
            }
            byteOffset += 5;
        }

        return packed;
    }

    function test_fips_pack_t1_first_four_coeffs() public {
        // Choose 4 sample 10-bit coefficients.
        uint16 c0 = 1;
        uint16 c1 = 512;
        uint16 c2 = 777;
        uint16 c3 = 1023;

        // Поточний FIPS-204 PK layout у контракті:
        // pkRaw = t1 (1920 bytes) || rho (32 bytes)
        // t1 = 6 поліномів по 320 байтів кожен → 6 * 320 = 1920.
        uint256 pkLen = 320 * 6 + 32;
        bytes memory pkRaw = new bytes(pkLen);

        // Pack first 4 coeffs of t1[0] into the first 5 bytes pkRaw[0..4].
        // У _decodeT1Packed ці 5 байтів інтерпретуються як перші 4 коефіцієнти t1.polys[0][0..3].
        bytes5 packed = _pack4x10(c0, c1, c2, c3);
        for (uint256 i = 0; i < 5; ++i) {
            pkRaw[i] = packed[i];
        }

        // Decode via harness.
        MLDSA65_Verifier_v2.DecodedPublicKey memory dpk = harness.exposedDecodePublicKey(pkRaw);

        // Check that t1[0].polys[0][0..3] match original coefficients.
        assertEq(int256(dpk.t1.polys[0][0]), int256(int32(uint32(c0))), "t1[0][0] mismatch");
        assertEq(int256(dpk.t1.polys[0][1]), int256(int32(uint32(c1))), "t1[0][1] mismatch");
        assertEq(int256(dpk.t1.polys[0][2]), int256(int32(uint32(c2))), "t1[0][2] mismatch");
        assertEq(int256(dpk.t1.polys[0][3]), int256(int32(uint32(c3))), "t1[0][3] mismatch");
    }

    function test_fips_pack_t1_full_poly_roundtrip() public {
        // Синтетичний повний поліном: різні значення, але в 10-бітному діапазоні.
        uint16[256] memory coeffs;
        for (uint256 i = 0; i < 256; ++i) {
            coeffs[i] = uint16((i * 7) % 1024);
        }

        // pkRaw = t1 (1920 bytes) || rho (32 bytes)
        uint256 pkLen = 320 * 6 + 32;
        bytes memory pkRaw = new bytes(pkLen);

        // Запаковуємо перший поліном t1[0] у перші 320 байтів.
        bytes memory packedPoly0 = _packPoly10(coeffs);
        for (uint256 i = 0; i < 320; ++i) {
            pkRaw[i] = packedPoly0[i];
        }

        // Decode via harness.
        MLDSA65_Verifier_v2.DecodedPublicKey memory dpk = harness.exposedDecodePublicKey(pkRaw);

        // Перевіряємо, що всі 256 коефіцієнтів t1[0] відновлюються коректно.
        for (uint256 i = 0; i < 256; ++i) {
            int32 expected = int32(uint32(coeffs[i]));
            int32 actual = dpk.t1.polys[0][i];

            assertEq(int256(actual), int256(expected), string.concat("t1[0][", vm.toString(i), "] mismatch"));
        }
    }
}
