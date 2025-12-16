// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_Verifier_v2.sol";

contract MLDSA_VerifyGas_Test is Test {
    MLDSA65_Verifier_v2 internal verifier;

    function setUp() public {
        verifier = new MLDSA65_Verifier_v2();
    }

    // -----------------------------
    //  Helpers: synthetic PK / SIG
    // -----------------------------

    function _makePkForGas() internal pure returns (MLDSA65_Verifier_v2.PublicKey memory pk) {
        // Повноцінний FIPS-розмір: 1952 байти = 1920 (t1) + 32 (rho)
        bytes memory raw = new bytes(1952);

        // Просто заповнюємо шумом 0x01, щоб декод мав реальну роботу
        for (uint256 i = 0; i < raw.length; ++i) {
            raw[i] = 0x01;
        }

        pk.raw = raw;
        return pk;
    }

    function _makeSigForGas()
        internal
        pure
        returns (MLDSA65_Verifier_v2.Signature memory sig, bytes32 cSeed)
    {
        // Повноцінний FIPS-розмір сигнатури ML-DSA-65: 3309 байтів
        bytes memory raw = new bytes(3309);

        // Заповнюємо z-частину шумом 0x01
        for (uint256 i = 0; i < raw.length; ++i) {
            raw[i] = 0x01;
        }

        // Детермінований non-zero seed для challenge
        cSeed = bytes32(uint256(0x42));

        // Останні 32 байти — це c
        uint256 offset = raw.length - 32;
        for (uint256 i = 0; i < 32; ++i) {
            raw[offset + i] = cSeed[i];
        }

        sig.raw = raw;
        return (sig, cSeed);
    }

    // -----------------------------
    //  Gas POC
    // -----------------------------

    function test_verify_gas_poc() public {
        MLDSA65_Verifier_v2.PublicKey memory pk = _makePkForGas();
        (MLDSA65_Verifier_v2.Signature memory sig, bytes32 cSeed) = _makeSigForGas();

        // ВАЖЛИВО:
        // Для нової FIPS-style логіки verify() ми мусимо
        // подати той самий seed і в сигнатурі (c), і в message_digest,
        // щоб poly_challenge(c) == poly_challenge(message_digest).
        bytes32 msgDigest = cSeed;

        uint256 gasBefore = gasleft();
        bool ok = verifier.verify(pk, sig, msgDigest);
        uint256 gasUsed = gasBefore - gasleft();

        // Лог для документації
        emit log_named_uint("verify() POC (decode + checks + w = A*z - c*t1) gas", gasUsed);

        // Ти зараз ~120–129M, даємо запас до 200M
        assertLt(gasUsed, 200_000_000);
        // Для gas-тесту нам важливо, щоб verify() не тільки не впав,
        // а й пройшов повний шлях з коректним challenge.
        assertTrue(ok, "verify() POC should accept structurally valid buffers");
    }
}
