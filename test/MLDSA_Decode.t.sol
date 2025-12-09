// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_Verifier_v2.sol";

contract MLDSA_DecodeHarness is MLDSA65_Verifier_v2 {
    function decodePk(bytes calldata raw)
        external
        pure
        returns (DecodedPublicKey memory)
    {
        return _decodePublicKey(raw);
    }

    function decodeSig(bytes calldata raw)
        external
        pure
        returns (DecodedSignature memory)
    {
        return _decodeSignature(raw);
    }
}

contract MLDSA_Decode_Test is Test {
    function test_decode_public_key_accepts_any_length_without_revert() public {
        MLDSA_DecodeHarness h = new MLDSA_DecodeHarness();

        bytes memory emptyPk = new bytes(0);
        bytes memory validPk = new bytes(1952);
        bytes memory invalidPk = new bytes(10);

        // Should not revert for any length.
        h.decodePk(emptyPk);
        h.decodePk(validPk);
        h.decodePk(invalidPk);
    }

    function test_decode_signature_accepts_any_length_without_revert() public {
        MLDSA_DecodeHarness h = new MLDSA_DecodeHarness();

        bytes memory emptySig = new bytes(0);
        bytes memory validSig = new bytes(3309);
        bytes memory invalidSig = new bytes(100);

        // Should not revert for any length.
        h.decodeSig(emptySig);
        h.decodeSig(validSig);
        h.decodeSig(invalidSig);
    }
}
