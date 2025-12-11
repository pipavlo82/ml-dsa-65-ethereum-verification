// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_Verifier_v2.sol";

contract MLDSA_RealVector_Test is Test {
    MLDSA65_Verifier_v2 verifier;

    function setUp() public {
        verifier = new MLDSA65_Verifier_v2();
    }

    function test_real_vector_decode_pipeline() public {
        // 1) Завантажуємо JSON з тестовим вектором (KAT)
        string memory json = vm.readFile("test_vectors/vector_001.json");

        // 2) Сирі PQ-поля з JSON
        bytes memory sigRaw = vm.parseJsonBytes(json, ".signature_raw");
        bytes memory pkRaw  = vm.parseJsonBytes(json, ".public_key_raw");

        // msg_hash збережений як hex-string, конвертимо в bytes32
        string memory msgHex = vm.parseJsonString(json, ".msg_hash");
        bytes32 msgHash = bytes32(vm.parseBytes(msgHex));

        // 3) Мапимо на нові ABI-структури v2
        MLDSA65_Verifier_v2.PublicKey memory pk =
            MLDSA65_Verifier_v2.PublicKey({raw: pkRaw});
        MLDSA65_Verifier_v2.Signature memory sig =
            MLDSA65_Verifier_v2.Signature({raw: sigRaw});

        // 4) Викликаємо verify — поки що це скелет, який завжди повертає false,
        //    але важливо, що весь decode/NTT/compute_w пайплайн не падає.
        bool ok = verifier.verify(pk, sig, msgHash);

        // Поки криптографія не реалізована, очікуємо false.
        assertFalse(ok);
    }
}
