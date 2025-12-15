// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {
    MLDSA65_ExpandA_KeccakFIPS204
} from "../contracts/verifier/MLDSA65_ExpandA_KeccakFIPS204.sol";

contract MLDSA_ExpandA_Keccak_FIPS204_KAT_Rho1 is Test {
    function test_expandA_keccak_fips_kat_rho1_row0_col0() public {
        // 1) Зчитуємо JSON із вектором
        string memory json = vm.readFile("test_vectors/expandA_keccak_fips_kat_rho1.json");

        string memory rhoHex = vm.parseJsonString(json, ".rho");
        uint256 row = vm.parseJsonUint(json, ".row");
        uint256 col = vm.parseJsonUint(json, ".col");
        string memory coeffsStr = vm.parseJsonString(json, ".coeffs");

        // 2) Парсимо rho як bytes32
        bytes32 rho = _parseHex32(rhoHex);

        // Очікуємо саме row=0, col=0 у цьому KAT
        assertEq(row, 0);
        assertEq(col, 0);

        // 3) Парсимо 256 коефіцієнтів із рядка
        int32[256] memory expected = _parseCoeffs(coeffsStr);

        // 4) Реальне ExpandA Keccak/FIPS
        int32[256] memory actual =
            MLDSA65_ExpandA_KeccakFIPS204.expandA_poly(rho, uint8(row), uint8(col));

        // 5) Порівнюємо поелементно
        for (uint256 i = 0; i < 256; ++i) {
            assertEq(actual[i], expected[i]);
        }
    }

    // ======================
    //  Helpers
    // ======================

    /// @notice Парсимо "0x..." (або без 0x) у bytes32.
    function _parseHex32(string memory hexStr) internal pure returns (bytes32) {
        bytes memory b = bytes(hexStr);
        uint256 len = b.length;
        require(len > 0, "empty rho hex");

        uint256 start = 0;
        if (len >= 2 && b[0] == "0" && (b[1] == "x" || b[1] == "X")) {
            start = 2;
        }

        require(len >= start + 64, "rho hex too short");

        uint256 acc = 0;
        for (uint256 i = 0; i < 32; ++i) {
            uint8 hi = _fromHexChar(b[start + 2 * i]);
            uint8 lo = _fromHexChar(b[start + 2 * i + 1]);
            uint8 byteVal = (hi << 4) | lo;
            acc = (acc << 8) | uint256(byteVal);
        }

        return bytes32(acc);
    }

    /// @notice Один hex-символ → його 4-бітове значення.
    function _fromHexChar(bytes1 c) internal pure returns (uint8) {
        if (c >= "0" && c <= "9") {
            return uint8(c) - uint8(bytes1("0"));
        }
        if (c >= "a" && c <= "f") {
            return 10 + (uint8(c) - uint8(bytes1("a")));
        }
        if (c >= "A" && c <= "F") {
            return 10 + (uint8(c) - uint8(bytes1("A")));
        }
        revert("invalid hex char");
    }

    /// @notice Парсить "51329,29682,...,931" у масив із 256 int32.
    function _parseCoeffs(string memory s) internal pure returns (int32[256] memory coeffs) {
        bytes memory b = bytes(s);
        uint256 len = b.length;
        uint256 idx = 0;
        uint256 outIdx = 0;

        while (idx < len) {
            // Пропускаємо пробіли та коми
            while (
                idx < len
                    && (b[idx] == " "
                        || b[idx] == ","
                        || b[idx] == "\n"
                        || b[idx] == "\r"
                        || b[idx] == "\t")
            ) {
                idx++;
            }
            if (idx >= len) {
                break;
            }

            // Опційний знак
            bool negative = false;
            if (b[idx] == "-") {
                negative = true;
                idx++;
            }

            // Цифри
            uint256 val = 0;
            bool hasDigit = false;
            while (idx < len) {
                bytes1 ch = b[idx];
                if (ch >= "0" && ch <= "9") {
                    uint256 digit = uint8(ch) - uint8(bytes1("0"));
                    val = val * 10 + digit;
                    hasDigit = true;
                    idx++;
                } else {
                    break;
                }
            }

            require(hasDigit, "invalid coeff token");
            require(outIdx < 256, "too many coeffs");

            int256 signedVal = negative ? -int256(val) : int256(val);
            coeffs[outIdx] = int32(signedVal);
            outIdx++;

            // Далі цикл знову пропустить роздільники
        }

        require(outIdx == 256, "expected 256 coeffs");
    }
}
