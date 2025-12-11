// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { MLDSA65_Poly } from "../contracts/verifier/MLDSA65_Verifier_v2.sol";

contract MLDSA_Poly_Test is Test {
    using MLDSA65_Poly for int32[256];

    int32 constant Q = 8380417;

    function test_poly_add_basic() public {
        int32[256] memory a;
        int32[256] memory b;

        a[0] = 1;
        b[0] = 2;

        int32[256] memory r = MLDSA65_Poly.add(a, b);

        assertEq(int256(r[0]), int256(3));
    }

    function test_poly_sub_basic() public {
        int32[256] memory a;
        int32[256] memory b;

        a[0] = 5;
        b[0] = 3;

        int32[256] memory r = MLDSA65_Poly.sub(a, b);

        assertEq(int256(r[0]), int256(2));
    }

    function test_poly_sub_wrap_mod_q() public {
        int32[256] memory a;
        int32[256] memory b;

        // a = 0, b = 1 → result should be Q - 1
        a[0] = 0;
        b[0] = 1;

        int32[256] memory r = MLDSA65_Poly.sub(a, b);

        assertEq(int256(r[0]), int256(Q - 1));
    }

    function test_poly_pointwise_mul_basic() public {
        int32[256] memory a;
        int32[256] memory b;

        a[0] = 2;
        b[0] = 3;

        int32[256] memory r = MLDSA65_Poly.pointwiseMul(a, b);

        // 2 * 3 = 6 mod Q
        assertEq(int256(r[0]), int256(6));
    }
}

