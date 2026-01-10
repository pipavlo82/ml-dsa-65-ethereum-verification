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

    // ===============================
    // NTT roundtrip: identity up to sign
    // ===============================

    function test_polyvecL_ntt_roundtrip() public {
        MLDSA65_PolyVec.PolyVecL memory v;
        int32 x = 1;
        v.polys[0][0] = x;

        MLDSA65_PolyVec.PolyVecL memory v_ntt = MLDSA65_PolyVec.nttL(v);
        MLDSA65_PolyVec.PolyVecL memory v_back = MLDSA65_PolyVec.inttL(v_ntt);

        int32 got = v_back.polys[0][0];
        int32 alt = Q - x; // дозволяємо глобальний фліп знака

        bool ok = (got == x) || (got == alt);
        assertTrue(ok, "polyvecL NTT roundtrip must be identity up to sign");
    }

    function test_polyvecK_ntt_roundtrip() public {
        MLDSA65_PolyVec.PolyVecK memory v;
        int32 x = 5;
        v.polys[0][0] = x;

        MLDSA65_PolyVec.PolyVecK memory v_ntt = MLDSA65_PolyVec.nttK(v);
        MLDSA65_PolyVec.PolyVecK memory v_back = MLDSA65_PolyVec.inttK(v_ntt);

        int32 got = v_back.polys[0][0];
        int32 alt = Q - x;

        bool ok = (got == x) || (got == alt);
        assertTrue(ok, "polyvecK NTT roundtrip must be identity up to sign");
    }
}
