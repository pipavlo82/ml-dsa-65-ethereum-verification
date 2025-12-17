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

        h.decodePk(emptyPk);
        h.decodePk(validPk);
        h.decodePk(invalidPk);
    }

    function test_decode_signature_accepts_any_length_without_revert() public {
        MLDSA_DecodeHarness h = new MLDSA_DecodeHarness();

        bytes memory emptySig = new bytes(0);
        bytes memory validSig = new bytes(3309);
        bytes memory invalidSig = new bytes(100);

        h.decodeSig(emptySig);
        h.decodeSig(validSig);
        h.decodeSig(invalidSig);
    }

    function test_decode_public_key_sets_rho_from_last_32_bytes() public {
        MLDSA_DecodeHarness h = new MLDSA_DecodeHarness();

        bytes memory pk = new bytes(1952);
        bytes32 rho = keccak256("mldsa-rho-test");

        assembly {
            mstore(
                add(add(pk, 32), sub(mload(pk), 32)),
                rho
            )
        }

        MLDSA65_Verifier_v2.DecodedPublicKey memory out = h.decodePk(pk);
        assertEq(out.rho, rho);
    }

    function test_decode_signature_sets_c_from_last_32_bytes() public {
        MLDSA_DecodeHarness h = new MLDSA_DecodeHarness();

        bytes memory sig = new bytes(3309);
        bytes32 c = keccak256("mldsa-c-test");

        assembly {
            mstore(
                add(add(sig, 32), sub(mload(sig), 32)),
                c
            )
        }

        MLDSA65_Verifier_v2.DecodedSignature memory out = h.decodeSig(sig);
        assertEq(out.c, c);
    }
}
