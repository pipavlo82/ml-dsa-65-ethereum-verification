// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_Verifier_v2.sol";

/// @notice POC end-to-end test for MLDSA65_Verifier_v2.verify().
/// @dev Uses zeroed FIPS-sized buffers to exercise the full decode + w = A*z - c*t1 path.
///      At this stage the verifier is a skeleton and is expected to return false.
contract MLDSA_Verify_POC_Test is Test {
    MLDSA65_Verifier_v2 internal verifier;

    function setUp() public {
        verifier = new MLDSA65_Verifier_v2();
    }

    /// @notice Verify runs to completion on FIPS-sized pk/sig buffers and returns false.
    /// @dev This exercises:
    ///  - FIPS public key decode path (t1 + rho) with len = 1952 bytes,
    ///  - FIPS signature decode path (z + c) with len = 3309 bytes,
    ///  - synthetic ExpandA + NTT layer,
    ///  - w = A*z - c*t1, where here c = 0 so we only run the A*z part.
    function test_verify_runs_on_fips_sized_buffers() public {
        // FIPS-204 ML-DSA-65 sizes:
        //  - pk: 1952 bytes (1920 t1 + 32 rho)
        //  - sig: 3309 bytes
        bytes memory pkRaw = new bytes(1952);
        bytes memory sigRaw = new bytes(3309);

        // Any non-zero message digest is fine for this POC.
        bytes32 msg = bytes32(uint256(0x01));

        bool ok = verifier.verify(
            MLDSA65_Verifier_v2.PublicKey({raw: pkRaw}),
            MLDSA65_Verifier_v2.Signature({raw: sigRaw}),
            msg
        );

        // At this stage verify() is a skeleton that always returns false.
        // The purpose of this test is structural: ensure no revert and full pipeline execution.
        assertFalse(ok);
    }
}
