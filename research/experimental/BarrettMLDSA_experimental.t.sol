// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/field/BarrettMLDSA.sol";

contract BarrettMLDSA_Test is Test {
    uint256 constant Q = BarrettMLDSA.Q;

    function _rand(uint256 seed, bytes32 salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(seed, salt))) % Q;
    }

    function test_BarrettMulMatchesMulmod() public {
        for (uint256 i = 0; i < 256; i++) {
            uint256 a = _rand(i, "a");
            uint256 b = _rand(i, "b");

            uint256 naive = mulmod(a, b, Q);
            uint256 br = BarrettMLDSA.mul(a, b);

            assertEq(br, naive, "Barrett mul != mulmod");
        }
    }

    function test_BarrettReduceMatchesMulmodOnProducts() public {
        // Тестуємо barrettReduce на всіх a*b (а не тільки через mul)
        for (uint256 i = 0; i < 256; i++) {
            uint256 a = _rand(i, "a");
            uint256 b = _rand(i, "b");
            uint256 x = a * b; // x < Q^2

            uint256 naive = x % Q;
            uint256 br = BarrettMLDSA.barrettReduce(x);

            assertEq(br, naive, "Barrett reduce != x % Q");
        }
    }

    function test_AddSubRoundtrip() public {
        for (uint256 i = 0; i < 256; i++) {
            uint256 a = _rand(i, "a");
            uint256 b = _rand(i, "b");

            uint256 c = BarrettMLDSA.add(a, b);
            uint256 back = BarrettMLDSA.sub(c, b);

            assertEq(back, a, "add/sub roundtrip failed");
        }
    }
}

// ------------------------------------------
// Gas benchmarks: mulmod vs Barrett mul
// ------------------------------------------
contract BarrettMLDSA_Gas_Test is Test {
    uint256 constant Q = BarrettMLDSA.Q;

    function _fillPoly(uint256 seed) internal pure returns (uint256[256] memory a) {
        for (uint256 i = 0; i < 256; i++) {
            a[i] = uint256(keccak256(abi.encodePacked(seed, i))) % Q;
        }
    }

    function _naiveMul(
        uint256[256] memory a,
        uint256[256] memory b
    ) internal pure returns (uint256[256] memory c) {
        unchecked {
            for (uint256 i = 0; i < 256; i++) {
                c[i] = mulmod(a[i], b[i], Q);
            }
        }
    }

    function _barrettMul(
        uint256[256] memory a,
        uint256[256] memory b
    ) internal pure returns (uint256[256] memory c) {
        unchecked {
            for (uint256 i = 0; i < 256; i++) {
                c[i] = BarrettMLDSA.mul(a[i], b[i]);
            }
        }
    }

    function test_NaivePolyMulGas() public {
        uint256[256] memory a = _fillPoly(1);
        uint256[256] memory b = _fillPoly(2);
        _naiveMul(a, b);
    }

    function test_BarrettPolyMulGas() public {
        uint256[256] memory a = _fillPoly(3);
        uint256[256] memory b = _fillPoly(4);
        _barrettMul(a, b);
    }

    function test_GasComparison() public {
        uint256[256] memory a = _fillPoly(11);
        uint256[256] memory b = _fillPoly(22);

        // 1) Naive mulmod
        uint256 gas1 = gasleft();
        for (uint256 i = 0; i < 256; i++) {
            mulmod(a[i], b[i], Q);
        }
        uint256 gasNaive = gas1 - gasleft();

        // 2) Barrett mul
        uint256 gas2 = gasleft();
        for (uint256 i = 0; i < 256; i++) {
            BarrettMLDSA.mul(a[i], b[i]);
        }
        uint256 gasBarrett = gas2 - gasleft();

        console.log("=== Barrett vs mulmod (256 coeffs) ===");
        console.log("Naive mulmod:  ", gasNaive, "gas");
        console.log("Barrett mul:   ", gasBarrett, "gas");

        if (gasBarrett <= gasNaive) {
            console.log("Barrett is cheaper by: ", gasNaive - gasBarrett, "gas");
        } else {
            console.log("Barrett is MORE expensive by: ", gasBarrett - gasNaive, "gas");
        }
    }
}
