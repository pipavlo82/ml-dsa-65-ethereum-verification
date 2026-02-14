// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {
    MLDSA65_Poly,
    MLDSA65_PolyVec
} from "../contracts/verifier/MLDSA65_Verifier_v2.sol";

contract MLDSA_PolyVec_Test is Test {
    using MLDSA65_Poly for int32[256];
    using MLDSA65_PolyVec for MLDSA65_PolyVec.PolyVecL;
    using MLDSA65_PolyVec for MLDSA65_PolyVec.PolyVecK;

    int32 constant Q = 8380417;

    function test_polyvecL_add_basic() public {
        MLDSA65_PolyVec.PolyVecL memory a;
        MLDSA65_PolyVec.PolyVecL memory b;

        a.polys[0][0] = 1;
        b.polys[0][0] = 2;

        MLDSA65_PolyVec.PolyVecL memory r = MLDSA65_PolyVec.addL(a, b);

        assertEq(int256(r.polys[0][0]), int256(3));
    }

    function test_polyvecL_sub_basic() public {
        MLDSA65_PolyVec.PolyVecL memory a;
        MLDSA65_PolyVec.PolyVecL memory b;

        a.polys[0][0] = 5;
        b.polys[0][0] = 3;

        MLDSA65_PolyVec.PolyVecL memory r = MLDSA65_PolyVec.subL(a, b);

        assertEq(int256(r.polys[0][0]), int256(2));
    }

    function test_polyvecL_sub_wrap_mod_q() public {
        MLDSA65_PolyVec.PolyVecL memory a;
        MLDSA65_PolyVec.PolyVecL memory b;

        a.polys[0][0] = 0;
        b.polys[0][0] = 1;

        MLDSA65_PolyVec.PolyVecL memory r = MLDSA65_PolyVec.subL(a, b);

        assertEq(int256(r.polys[0][0]), int256(Q - 1));
    }

    function test_polyvecK_add_basic() public {
        MLDSA65_PolyVec.PolyVecK memory a;
        MLDSA65_PolyVec.PolyVecK memory b;

        a.polys[0][0] = 7;
        b.polys[0][0] = 1;

        MLDSA65_PolyVec.PolyVecK memory r = MLDSA65_PolyVec.addK(a, b);

        assertEq(int256(r.polys[0][0]), int256(8));
    }

    function test_polyvecK_sub_basic() public {
        MLDSA65_PolyVec.PolyVecK memory a;
        MLDSA65_PolyVec.PolyVecK memory b;

        a.polys[0][0] = 10;
        b.polys[0][0] = 3;

        MLDSA65_PolyVec.PolyVecK memory r = MLDSA65_PolyVec.subK(a, b);

        assertEq(int256(r.polys[0][0]), int256(7));
    }

    function test_polyvecL_ntt_identity_placeholder() public {
        // NTT wrapper is currently an identity placeholder.
        MLDSA65_PolyVec.PolyVecL memory v;
        v.polys[0][0] = 42;

        MLDSA65_PolyVec.PolyVecL memory w = MLDSA65_PolyVec.nttL(v);
        assertEq(int256(w.polys[0][0]), int256(42));

        w = MLDSA65_PolyVec.inttL(v);
        assertEq(int256(w.polys[0][0]), int256(42));
    }

    function test_polyvecK_ntt_identity_placeholder() public {
        MLDSA65_PolyVec.PolyVecK memory v;
        v.polys[0][0] = 13;

        MLDSA65_PolyVec.PolyVecK memory w = MLDSA65_PolyVec.nttK(v);
        assertEq(int256(w.polys[0][0]), int256(13));

        w = MLDSA65_PolyVec.inttK(v);
        assertEq(int256(w.polys[0][0]), int256(13));
    }
}

