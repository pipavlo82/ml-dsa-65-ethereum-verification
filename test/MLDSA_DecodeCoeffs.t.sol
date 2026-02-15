// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_Verifier_v2.sol";

/// @notice Harness для доступу до внутрішніх decode-хелперів.
contract MLDSA_DecodeCoeffs_Harness is MLDSA65_Verifier_v2 {
    function exposedDecodePublicKey(bytes memory raw)
        external
        pure
        returns (DecodedPublicKey memory)
    {
        PublicKey memory pk = PublicKey({raw: raw});
        return _decodePublicKey(pk);
    }

    function exposedDecodeSignature(bytes memory raw)
        external
        pure
        returns (DecodedSignature memory)
    {
        Signature memory sig = Signature({raw: raw});
        return _decodeSignature(sig);
    }
}

contract MLDSA_DecodeCoeffs_Test is Test {
    MLDSA_DecodeCoeffs_Harness internal harness;

    function setUp() public {
        harness = new MLDSA_DecodeCoeffs_Harness();
    }

    /// @dev Пакує 4×10-бітні коефіцієнти в 5 байт (FIPS-204 / Dilithium layout).
    ///      Такий самий layout, як у MLDSA_FIPSPack_t1.t.sol.
    function _pack4x10(
        uint16 t0,
        uint16 t1,
        uint16 t2,
        uint16 t3
    ) internal pure returns (bytes5 outBytes) {
        require(t0 < 1024 && t1 < 1024 && t2 < 1024 && t3 < 1024, "coeff out of range");

        uint64 acc = uint64(t0)
            | (uint64(t1) << 10)
            | (uint64(t2) << 20)
            | (uint64(t3) << 30);

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

    function test_decode_public_key_first_four_t1_coeffs() public {
        // Мінімально достатня довжина:
        // 32 байти під rho + 5 байт під перший блок t1[0].
        uint256 pkLen = 32 + 5;
        bytes memory pkRaw = new bytes(pkLen);

        // Цільові 10-бітні коефіцієнти t1[0][0..3].
        uint16 c0 = 1;
        uint16 c1 = 2;
        uint16 c2 = 3;
        uint16 c3 = 4;

        // Пакуємо 4×10 біт у 5 байт і кладемо в pkRaw[32..36],
        // як у справжньому FIPS-204 layout: rho || t1[0] || ...
        bytes5 packed = _pack4x10(c0, c1, c2, c3);
        for (uint256 i = 0; i < 5; ++i) {
            pkRaw[32 + i] = packed[i];
        }

        MLDSA65_Verifier_v2.DecodedPublicKey memory dpk =
            harness.exposedDecodePublicKey(pkRaw);

        // Перевіряємо, що декодовані t1[0].polys[0][0..3] збігаються.
        assertEq(
            int256(dpk.t1.polys[0][0]),
            int256(int32(uint32(c0))),
            "t1[0][0] mismatch"
        );
        assertEq(
            int256(dpk.t1.polys[0][1]),
            int256(int32(uint32(c1))),
            "t1[0][1] mismatch"
        );
        assertEq(
            int256(dpk.t1.polys[0][2]),
            int256(int32(uint32(c2))),
            "t1[0][2] mismatch"
        );
        assertEq(
            int256(dpk.t1.polys[0][3]),
            int256(int32(uint32(c3))),
            "t1[0][3] mismatch"
        );
    }

    function test_decode_signature_first_four_z_coeffs() public {
        // Достатньо байтів, щоб пройти length-guard у _decodeSignature.
        bytes memory sigRaw = new bytes(64);

        // Цільові коефіцієнти для z.polys[0][0..3].
        int32[4] memory coeffs =
            [int32(10), int32(20), int32(30), int32(40)];

        // Кодуємо кожен coeff як 4-байтовий little-endian.
        for (uint256 i = 0; i < 4; ++i) {
            uint32 v = uint32(uint32(coeffs[i]));
            uint256 off = 4 * i;

            sigRaw[off + 0] = bytes1(uint8(v & 0xff));
            sigRaw[off + 1] = bytes1(uint8((v >> 8) & 0xff));
            sigRaw[off + 2] = bytes1(uint8((v >> 16) & 0xff));
            sigRaw[off + 3] = bytes1(uint8((v >> 24) & 0xff));
        }

        MLDSA65_Verifier_v2.DecodedSignature memory dsig =
            harness.exposedDecodeSignature(sigRaw);

        for (uint256 i = 0; i < 4; ++i) {
            assertEq(
                int256(dsig.z.polys[0][i]),
                int256(coeffs[i]),
                "z[0][i] mismatch"
            );
        }
    }
}
