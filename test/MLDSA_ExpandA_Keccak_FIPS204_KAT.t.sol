// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MLDSA65_ExpandA_KeccakFIPS204} from "../contracts/verifier/MLDSA65_ExpandA_KeccakFIPS204.sol";

contract MLDSA_ExpandA_Keccak_FIPS204_KAT_Test is Test {
    uint256 constant K = 6;
    uint256 constant L = 5;
    uint256 constant N = 256;
    uint256 constant Q = 8380417;

    function test_expandA_keccak_fips_kat_row0_col0() public {
        // 1) Читаємо JSON із KAT
        string memory path = string(abi.encodePacked(vm.projectRoot(), "/test_vectors/expandA_keccak_fips_kat.json"));
        string memory json = vm.readFile(path);

        // 2) Базові метадані
        string memory name = vm.parseJsonString(json, ".vector.name");
        assertEq(name, "expandA_keccak_fips_kat_row0_col0");

        uint256 k = vm.parseJsonUint(json, ".vector.params.k");
        uint256 l = vm.parseJsonUint(json, ".vector.params.l");
        uint256 n = vm.parseJsonUint(json, ".vector.params.n");
        uint256 q = vm.parseJsonUint(json, ".vector.params.q");

        assertEq(k, K);
        assertEq(l, L);
        assertEq(n, N);
        assertEq(q, Q);

        uint256 row = vm.parseJsonUint(json, ".vector.row");
        uint256 col = vm.parseJsonUint(json, ".vector.col");

        assertLt(row, K, "row must be < K");
        assertLt(col, L, "col must be < L");

        // 3) Поки що rho беремо як константу (0x00…00).
        //    Потім замінимо на реальний rho з JSON, коли підтягнемо KAT.
        bytes32 rho = bytes32(0);

        // 4) poly з JSON: варіативної довжини, але не порожній
        bytes memory polyEncoded = vm.parseJson(json, ".vector.poly");
        uint256[] memory poly = abi.decode(polyEncoded, (uint256[]));
        assertGt(poly.length, 0, "poly must be non-empty");

        // Перевіряємо тільки перші min(poly.length, N) коефіцієнтів
        uint256 checkLen = poly.length;
        if (checkLen > N) {
            checkLen = N;
        }

        // 5) Обчислюємо A[row][col] через реальний Keccak/FIPS-204 ExpandA
        int32[256] memory a = MLDSA65_ExpandA_KeccakFIPS204.expandA_poly(rho, uint8(row), uint8(col));

        // 6) Порівнюємо коефіцієнти
        for (uint256 i = 0; i < checkLen; ++i) {
            uint256 ai = uint256(int256(a[i]));
            assertEq(ai, poly[i], string(abi.encodePacked("coeff mismatch at i=", vm.toString(i))));
        }
    }
}
