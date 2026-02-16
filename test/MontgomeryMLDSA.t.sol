// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/field/MontgomeryMLDSA.sol";

// ---------------------------------------------------------
// Коректність Montgomery для ML-DSA-65
// ---------------------------------------------------------
contract MontgomeryMLDSA_Test is Test {
    function _rand(uint256 seed, bytes32 salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(seed, salt))) % MontgomeryMLDSA.Q;
    }

    function test_MontgomeryMulMatchesMulmod() public {
        for (uint256 i = 0; i < 256; i++) {
            uint256 a = _rand(i, "a");
            uint256 b = _rand(i, "b");

            uint256 naive = mulmod(a, b, MontgomeryMLDSA.Q);

            // → Montgomery-домен
            uint256 aM = MontgomeryMLDSA.toMontgomery(a);
            uint256 bM = MontgomeryMLDSA.toMontgomery(b);

            // множення в Montgomery-домені
            uint256 abM = MontgomeryMLDSA.montgomeryMul(aM, bM);

            // назад у звичайний домен
            uint256 result = MontgomeryMLDSA.fromMontgomery(abM);

            assertEq(result, naive, "Montgomery != mulmod");
        }
    }

    function test_ToFromMontgomeryRoundtrip() public {
        for (uint256 i = 0; i < 256; i++) {
            uint256 x = _rand(i, "x");

            uint256 xm = MontgomeryMLDSA.toMontgomery(x);
            uint256 back = MontgomeryMLDSA.fromMontgomery(xm);

            assertEq(back, x, "Roundtrip failed");
        }
    }
}

// ---------------------------------------------------------
// Газ-бенч: mulmod vs Montgomery на векторі 256 елементів
// ---------------------------------------------------------
contract MontgomeryMLDSA_Gas_Test is Test {
    uint256 constant Q = MontgomeryMLDSA.Q;

    function _fillPoly(uint256 seed) internal pure returns (uint256[256] memory a) {
        for (uint256 i = 0; i < 256; i++) {
            a[i] = uint256(keccak256(abi.encodePacked(seed, i))) % Q;
        }
    }

    // Базова реалізація: mulmod на кожному коефіцієнті
    function _naivePolyMul(uint256[256] memory a, uint256[256] memory b) internal pure returns (uint256[256] memory c) {
        unchecked {
            for (uint256 i = 0; i < 256; i++) {
                c[i] = mulmod(a[i], b[i], Q);
            }
        }
    }

    // "Найгірший" Montgomery: з конверсіями для кожного коефіцієнта
    function _montPolyMul_Full(uint256[256] memory a, uint256[256] memory b)
        internal
        pure
        returns (uint256[256] memory c)
    {
        unchecked {
            for (uint256 i = 0; i < 256; i++) {
                uint256 aM = MontgomeryMLDSA.toMontgomery(a[i]);
                uint256 bM = MontgomeryMLDSA.toMontgomery(b[i]);
                uint256 prodM = MontgomeryMLDSA.montgomeryMul(aM, bM);
                c[i] = MontgomeryMLDSA.fromMontgomery(prodM);
            }
        }
    }

    // Реалістичний сценарій NTT:
    // масиви вже в Montgomery-домені, множення лише montgomeryMul
    function _montPolyMul_Preconverted(uint256[256] memory aM, uint256[256] memory bM)
        internal
        pure
        returns (uint256[256] memory c)
    {
        unchecked {
            for (uint256 i = 0; i < 256; i++) {
                c[i] = MontgomeryMLDSA.montgomeryMul(aM[i], bM[i]);
            }
        }
    }

    // 🔎 Газ для "простого" mulmod по вектору 256 елементів
    function test_NaivePolyMulGas() public {
        uint256[256] memory a = _fillPoly(1);
        uint256[256] memory b = _fillPoly(2);
        _naivePolyMul(a, b);
    }

    // 🔎 Газ для Montgomery-векторного множення (з конверсіями на кожен елемент)
    function test_MontPolyMulGas() public {
        uint256[256] memory a = _fillPoly(3);
        uint256[256] memory b = _fillPoly(4);
        _montPolyMul_Full(a, b);
    }

    /// @notice Реалістичний NTT-сценарій:
    ///         дані вже збережені в Montgomery-формі (як публічний ключ)
    function test_MontPolyMulPreconvertedGas() public {
        uint256[256] memory a;
        uint256[256] memory b;

        // Одноразова конверсія, як при збереженні PK в storage
        for (uint256 i = 0; i < 256; i++) {
            a[i] = MontgomeryMLDSA.toMontgomery(uint256(keccak256(abi.encodePacked(i, "a"))) % Q);
            b[i] = MontgomeryMLDSA.toMontgomery(uint256(keccak256(abi.encodePacked(i, "b"))) % Q);
        }

        uint256[256] memory c;
        for (uint256 i = 0; i < 256; i++) {
            c[i] = MontgomeryMLDSA.montgomeryMul(a[i], b[i]);
        }
    }

    /// @notice Повний порівняльний репорт з розкладом по компонентам
    function test_GasComparison() public {
        uint256[256] memory a;
        uint256[256] memory b;

        // Вихідні дані в звичайному домені
        for (uint256 i = 0; i < 256; i++) {
            a[i] = uint256(keccak256(abi.encodePacked(i, "a"))) % Q;
            b[i] = uint256(keccak256(abi.encodePacked(i, "b"))) % Q;
        }

        // 1) Naive mulmod baseline
        uint256 gas1 = gasleft();
        for (uint256 i = 0; i < 256; i++) {
            mulmod(a[i], b[i], Q);
        }
        uint256 gasNaive = gas1 - gasleft();

        // 2) Montgomery з конверсіями на кожному елементі (найгірший сценарій)
        uint256 gas2 = gasleft();
        for (uint256 i = 0; i < 256; i++) {
            uint256 aM = MontgomeryMLDSA.toMontgomery(a[i]);
            uint256 bM = MontgomeryMLDSA.toMontgomery(b[i]);
            MontgomeryMLDSA.fromMontgomery(MontgomeryMLDSA.montgomeryMul(aM, bM));
        }
        uint256 gasMontFull = gas2 - gasleft();

        // 3) Pre-converted Montgomery (реалістичний NTT-сценарій)
        uint256[256] memory aMArr;
        uint256[256] memory bMArr;
        for (uint256 i = 0; i < 256; i++) {
            aMArr[i] = MontgomeryMLDSA.toMontgomery(a[i]);
            bMArr[i] = MontgomeryMLDSA.toMontgomery(b[i]);
        }

        uint256 gas3 = gasleft();
        for (uint256 i = 0; i < 256; i++) {
            MontgomeryMLDSA.montgomeryMul(aMArr[i], bMArr[i]);
        }
        uint256 gasMontPreconv = gas3 - gasleft();

        console.log("=== Polynomial Multiply (256 coefficients) ===");
        console.log("");
        console.log("1. Naive mulmod:               ", gasNaive, "gas");
        console.log("2. Montgomery (with conv):     ", gasMontFull, "gas");
        console.log("3. Montgomery (pre-converted): ", gasMontPreconv, "gas");
        console.log("");

        uint256 savings = gasNaive > gasMontPreconv ? gasNaive - gasMontPreconv : 0;

        uint256 improvement = gasNaive > gasMontPreconv ? (savings * 100) / gasNaive : 0;

        console.log("Savings (preconv vs naive):    ", savings, "gas");
        console.log("Improvement:                   ", improvement, "%");
        console.log("");
        console.log("Cost breakdown:");
        console.log("  - Conversions overhead: ", gasMontFull - gasMontPreconv, "gas");
        console.log("  - Pure Montgomery mul:  ", gasMontPreconv, "gas");
    }
}
