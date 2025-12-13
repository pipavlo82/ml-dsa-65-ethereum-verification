// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../solidity/MLDSA65Verifier.sol";

contract MLDSA_StructuralParser_Test is Test {
    MLDSA65Verifier verifier;

    function setUp() public {
        verifier = new MLDSA65Verifier();
    }

    function test_structural_parsing() public {
        // Load JSON with real ML-DSA-65 vectors
        string memory json = vm.readFile("test_vectors/vector_001.json");

        bytes memory signature = vm.parseJsonBytes(json, ".signature_raw");
        bytes memory publicKey = vm.parseJsonBytes(json, ".public_key_raw");
        bytes memory msgHashBytes = vm.parseJsonBytes(json, ".msg_hash");

        require(msgHashBytes.length == 32, "msg_hash must be 32 bytes");
        bytes32 msgHash = bytes32(msgHashBytes);

        uint256 beforeGas = gasleft();
        verifier.verify(signature, msgHash, publicKey);
        uint256 gasUsed = beforeGas - gasleft();

        console.log("Structural gas:", gasUsed);

        // Realistic ML-DSA-65 gas bounds (parsing only)
        assertGt(gasUsed, 200000);
        assertLt(gasUsed, 400000);
    }

    function test_invalid_signature_length() public {
        bytes memory badSig = new bytes(100); // Too short
        bytes memory pubkey = new bytes(1952); // Correct length
        bytes32 msgHash = bytes32(0);

        vm.expectRevert("Invalid sig length");
        verifier.verify(badSig, msgHash, pubkey);
    }

    function test_invalid_pubkey_length() public {
        bytes memory sig = new bytes(3309); // Correct length
        bytes memory badPubkey = new bytes(100); // Too short
        bytes32 msgHash = bytes32(0);

        vm.expectRevert("Invalid pk length");
        verifier.verify(sig, msgHash, badPubkey);
    }
}
