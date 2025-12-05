// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

import "../solidity/IPQVerifier.sol";

contract MLDSA_Verify_Test is Test {
    using stdJson for string;

    IPQVerifier verifier;

    function setUp() public {
        verifier = new IPQVerifier();
    }

    function test_verify_real_vector() public {
        // Load vector JSON
        string memory raw = vm.readFile("test_vectors/vector_001.json");

        // Extract PQ fields
        string memory pk_b64  = raw.readString(".pq_pubkey_b64");
        string memory sig_b64 = raw.readString(".sig_pq_b64");

        bytes memory pk  = vm.parseBytes(base64Decode(pk_b64));
        bytes memory sig = vm.parseBytes(base64Decode(sig_b64));

        // Message = msg_hash (bytes32)
        string memory hash_hex = raw.readString(".msg_hash");
        bytes32 msgHash = vm.parseBytes32(hash_hex);

        // Convert the msgHash bytes32 into a raw bytes message
        bytes memory message = abi.encodePacked(msgHash);

        bool ok = verifier.verify(message, pk, sig);

        assertTrue(ok, "ML-DSA-65 verification failed");
    }

    // ---------------------------------------------------------
    // Base64 decode for Foundry
    // ---------------------------------------------------------
    function base64Decode(string memory data)
        internal
        pure
        returns (bytes memory)
    {
        return vm.parseBytes(vm.toString(vm.ffi(
            abi.encodePacked("bash", "-c", "echo " , data , " | base64 -d | xxd -p")
        )));
    }
}
