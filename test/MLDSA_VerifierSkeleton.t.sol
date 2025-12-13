// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_Verifier_v2.sol";

contract MLDSA_VerifierSkeleton_Test is Test {
    function test_verify_default_returns_false() public {
        MLDSA65_Verifier_v2.PublicKey memory pk =
            MLDSA65_Verifier_v2.PublicKey({ raw: new bytes(0) });

        MLDSA65_Verifier_v2.Signature memory sig =
            MLDSA65_Verifier_v2.Signature({ raw: new bytes(0) });

        MLDSA65_Verifier_v2 verifier = new MLDSA65_Verifier_v2();

        bool ok = verifier.verify(pk, sig, bytes32(0));
        assertFalse(ok);
    }
}
