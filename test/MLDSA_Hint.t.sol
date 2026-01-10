// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {
    MLDSA65_PolyVec,
    MLDSA65_Hint
} from "../contracts/verifier/MLDSA65_Verifier_v2.sol";

contract MLDSA_Hint_Test is Test {
    using MLDSA65_Hint for MLDSA65_Hint.HintVecL;

    int32 constant Q = 8380417;

    function test_hint_valid_range() public {
        MLDSA65_Hint.HintVecL memory h;

        // Set a few sample flags in {-1, 0, 1}
        h.flags[0][0] = 0;
        h.flags[0][1] = 1;
        h.flags[0][2] = -1;

        bool ok = MLDSA65_Hint.isValidHint(h);
        assertTrue(ok);
    }

    function test_hint_invalid_range() public {
        MLDSA65_Hint.HintVecL memory h;

        // Everything is default 0, but we set one flag out of range.
        h.flags[0][0] = 2;

        bool ok = MLDSA65_Hint.isValidHint(h);
        assertFalse(ok);
    }

    function test_apply_hint_identity_placeholder() public {
        // For now applyHintL should act as an identity.
        MLDSA65_PolyVec.PolyVecL memory w;
        MLDSA65_Hint.HintVecL memory h;

        w.polys[0][0] = 123;
        h.flags[0][0] = 0;

        MLDSA65_PolyVec.PolyVecL memory out =
            MLDSA65_Hint.applyHintL(w, h);

        assertEq(int256(out.polys[0][0]), int256(123));
    }
}
