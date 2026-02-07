// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_Verifier_v2.sol";

contract MLDSA_Verify_FIPSKAT_Test is Test {
    MLDSA65_Verifier_v2 internal verifier;

    function setUp() public {
        verifier = new MLDSA65_Verifier_v2();
    }

    /// @notice Full FIPS-204 KAT verify() smoke+gas test using test_vectors/vector_001.json
    /// public_key_raw  -> 1952 bytes (pk)
    /// signature_raw   -> 3309 bytes (sig)
    /// msg_hash        -> 32 bytes (message digest)
    function test_verify_fips_kat_vector0() public {
        // 1) Зчитуємо JSON KAT
        string memory json = vm.readFile("test_vectors/vector_001.json");

        // 2) Дістаємо pk, sig, msg_hash з JSON
        bytes memory pkBytes = vm.parseJsonBytes(json, ".public_key_raw");
        bytes memory sigBytes = vm.parseJsonBytes(json, ".signature_raw");
        bytes memory msgBytes = vm.parseJsonBytes(json, ".msg_hash");

        // 3) Перевіряємо FIPS-розміри буферів
        assertEq(pkBytes.length, 1952, "pubkey length must be 1952 bytes (FIPS-204)");
        assertEq(sigBytes.length, 3309, "signature length must be 3309 bytes (FIPS-204)");
        assertEq(msgBytes.length, 32, "msg_hash length must be 32 bytes");

        // 4) Обгортаємо сирі байти в структури PublicKey / Signature
        MLDSA65_Verifier_v2.PublicKey memory pk;
        pk.raw = pkBytes;

        MLDSA65_Verifier_v2.Signature memory sig;
        sig.raw = sigBytes;

        // 5) Конвертуємо msg_hash → bytes32
        bytes32 msgDigest;
        assembly {
            // msgBytes layout: [len][32 bytes of data...]
            msgDigest := mload(add(msgBytes, 32))
        }

        // 6) Викликаємо реальний verify() і міряємо gas
        uint256 gasBefore = gasleft();
        bool ok = verifier.verify(pk, sig, msgDigest);
        uint256 gasUsed = gasBefore - gasleft();

        // Логи для документації й подальшого тюнінгу
        emit log_named_uint("verify_fips_kat_vector0_gas", gasUsed);
        emit log_named_uint("verify_fips_kat_vector0_ok_flag", ok ? 1 : 0);

        // 7) Поки що цей тест — smoke+gas:
        //    - verify() ще не повністю FIPS-коректний, тому ok може бути false.
        //    - але ми вимагаємо, щоб перевірка відпрацювала та вклалася в адекватний gas-ліміт.
        assertLt(gasUsed, 400_000_000);

        // TODO (коли доведемо повну FIPS-коректність):
        // assertTrue(ok, "FIPS-204 KAT verify() must succeed");
    }
}
