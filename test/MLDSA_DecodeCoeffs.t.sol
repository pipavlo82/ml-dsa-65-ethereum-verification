// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_Verifier_v2.sol";

contract MLDSA_DecodeCoeffs_Test is Test, MLDSA65_Verifier_v2 {
    // Build a synthetic pk.raw where the first 4 coefficients of t1[0]
    // are encoded as 4-byte little-endian integers at the beginning,
    // and the last 32 bytes hold rho.
    function _buildPkRawWithCoeffs(
        int32[4] memory coeffs
    ) internal pure returns (bytes memory) {
        // 16 bytes for 4 coefficients + 32 bytes for rho
        bytes memory pk = new bytes(16 + 32);

        // encode coefficients at offsets 0, 4, 8, 12
        for (uint256 i = 0; i < 4; ++i) {
            uint32 v = uint32(uint32(uint256(int256(coeffs[i]))));
            uint256 off = i * 4;
            pk[off] = bytes1(uint8(v & 0xff));
            pk[off + 1] = bytes1(uint8((v >> 8) & 0xff));
            pk[off + 2] = bytes1(uint8((v >> 16) & 0xff));
            pk[off + 3] = bytes1(uint8((v >> 24) & 0xff));
        }

        // rho in the last 32 bytes (any non-zero pattern is fine for this test)
        bytes32 rhoValue = keccak256("rho-test");
        uint256 rhoOffset = pk.length - 32;
        for (uint256 j = 0; j < 32; ++j) {
            pk[rhoOffset + j] = rhoValue[j];
        }

        return pk;
    }

    // Build a synthetic sig.raw where the first 4 coefficients of z[0]
    // are encoded as 4-byte little-endian integers at the beginning,
    // and the last 32 bytes hold c.
    function _buildSigRawWithCoeffs(
        int32[4] memory coeffs
    ) internal pure returns (bytes memory) {
        // 16 bytes for 4 coefficients + 32 bytes for c
        bytes memory sig = new bytes(16 + 32);

        for (uint256 i = 0; i < 4; ++i) {
            uint32 v = uint32(uint32(uint256(int256(coeffs[i]))));
            uint256 off = i * 4;
            sig[off] = bytes1(uint8(v & 0xff));
            sig[off + 1] = bytes1(uint8((v >> 8) & 0xff));
            sig[off + 2] = bytes1(uint8((v >> 16) & 0xff));
            sig[off + 3] = bytes1(uint8((v >> 24) & 0xff));
        }

        bytes32 cValue = keccak256("c-test");
        uint256 cOffset = sig.length - 32;
        for (uint256 j = 0; j < 32; ++j) {
            sig[cOffset + j] = cValue[j];
        }

        return sig;
    }

    function test_decode_public_key_first_four_t1_coeffs() public {
        int32[4] memory coeffs = [int32(1), int32(123456), int32(42), int32(8380416)];
        bytes memory pkRaw = _buildPkRawWithCoeffs(coeffs);

        DecodedPublicKey memory dpk = _decodePublicKey(pkRaw);

        for (uint256 i = 0; i < 4; ++i) {
            assertEq(
                int256(dpk.t1.polys[0][i]),
                int256(coeffs[i]),
                "t1[0][i] must match encoded coefficient"
            );
        }
    }

    function test_decode_signature_first_four_z_coeffs() public {
        int32[4] memory coeffs = [int32(7), int32(1000000), int32(123), int32(50000)];
        bytes memory sigRaw = _buildSigRawWithCoeffs(coeffs);

        DecodedSignature memory dsig = _decodeSignature(sigRaw);

        for (uint256 i = 0; i < 4; ++i) {
            assertEq(
                int256(dsig.z.polys[0][i]),
                int256(coeffs[i]),
                "z[0][i] must match encoded coefficient"
            );
        }
    }
}
