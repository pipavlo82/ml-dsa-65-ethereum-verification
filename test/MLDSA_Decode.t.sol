// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_Verifier_v2.sol";

contract MLDSA_Decode_Harness is MLDSA65_Verifier_v2 {
    function exposedDecodePublicKey(bytes calldata raw)
        external
        pure
        returns (DecodedPublicKey memory)
    {
        PublicKey memory pk = PublicKey({raw: raw});
        return _decodePublicKey(pk);
    }

    function exposedDecodeSignature(bytes calldata raw)
        external
        pure
        returns (DecodedSignature memory)
    {
        Signature memory sig = Signature({raw: raw});
        return _decodeSignature(sig);
    }
}

contract MLDSA_Decode_Test is Test {
    MLDSA_Decode_Harness internal harness;

    function setUp() public {
        harness = new MLDSA_Decode_Harness();
    }

    function test_decode_public_key_accepts_any_length_without_revert() public {
        bytes memory raw = new bytes(16);
        harness.exposedDecodePublicKey(raw);
    }

    function test_decode_signature_accepts_any_length_without_revert() public {
        bytes memory raw = new bytes(16);
        harness.exposedDecodeSignature(raw);
    }

    function test_decode_public_key_sets_rho_from_last_32_bytes() public {
        bytes memory raw = new bytes(64);

        bytes32 rho =
            hex"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f";

        // write rho into last 32 bytes of pk
        for (uint256 i = 0; i < 32; ++i) {
            raw[raw.length - 32 + i] = rho[i];
        }

        MLDSA65_Verifier_v2.DecodedPublicKey memory dpk =
            harness.exposedDecodePublicKey(raw);

        assertEq(dpk.rho, rho);
    }

    function test_decode_signature_sets_c_from_last_32_bytes() public {
        bytes memory raw = new bytes(96);

        bytes32 c =
            hex"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

        // write c into last 32 bytes of sig
        for (uint256 i = 0; i < 32; ++i) {
            raw[raw.length - 32 + i] = c[i];
        }

        MLDSA65_Verifier_v2.DecodedSignature memory dsig =
            harness.exposedDecodeSignature(raw);

        assertEq(dsig.c, c);
    }
}
