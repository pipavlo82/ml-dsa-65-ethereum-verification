// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MLDSA65_Verifier_v2} from "../contracts/verifier/MLDSA65_Verifier_v2.sol";

contract MLDSA_VerifyGas_Test is Test {
    MLDSA65_Verifier_v2 internal verifier;

    // FIPS-204 sizes for ML-DSA-65 (Dilithium3 parameters)
    uint256 internal constant PK_LEN = 1952;
    uint256 internal constant SIG_LEN = 3309;

    function setUp() public {
        verifier = new MLDSA65_Verifier_v2();
    }

    /// @notice Build a structurally valid FIPS-sized public key:
    ///         - 1952 bytes total
    ///         - last 32 bytes = rho != 0
    ///         - first 1920 bytes (t1) all zeros
    function _buildPk() internal pure returns (bytes memory) {
        bytes memory pkRaw = new bytes(PK_LEN);

        // By default everything is zero; we only need rho != 0 at the end.
        uint256 rhoOffset = PK_LEN - 32;
        for (uint256 i = 0; i < 32; ++i) {
            pkRaw[rhoOffset + i] = bytes1(uint8(i + 1)); // simple non-zero pattern
        }

        return pkRaw;
    }

    /// @notice Build a structurally valid FIPS-sized signature:
    ///         - 3309 bytes total
    ///         - last 32 bytes = c != 0
    ///         - prefix used for z-coefficients is all zeros
    ///           → z = 0, which trivially passes the loose norm check.
    function _buildSig() internal pure returns (bytes memory) {
        bytes memory sigRaw = new bytes(SIG_LEN);

        // All bytes initially zero → z will be all zeros.
        // Ensure last 32 bytes (c) are non-zero.
        uint256 cOffset = SIG_LEN - 32;
        for (uint256 i = 0; i < 32; ++i) {
            sigRaw[cOffset + i] = bytes1(uint8(0xA0 + i)); // arbitrary non-zero pattern
        }

        return sigRaw;
    }

    function test_verify_gas_poc() public {
        bytes memory pkRaw = _buildPk();
        bytes memory sigRaw = _buildSig();

        MLDSA65_Verifier_v2.PublicKey memory pk =
            MLDSA65_Verifier_v2.PublicKey({raw: pkRaw});
        MLDSA65_Verifier_v2.Signature memory sig =
            MLDSA65_Verifier_v2.Signature({raw: sigRaw});

        bytes32 messageDigest = keccak256("ml-dsa-65-gas-poc");

        uint256 gasBefore = gasleft();
        bool ok = verifier.verify(pk, sig, messageDigest);
        uint256 gasAfter = gasleft();

        uint256 gasUsed = gasBefore - gasAfter;

        // Sanity: under POC rules, this signature should be accepted structurally.
        assertTrue(ok, "verify() POC should accept structurally valid buffers");

        emit log_named_uint(
            "verify() POC (decode + checks + w = A*z - c*t1) gas",
            gasUsed
        );
    }
}

