// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MLDSA65_ExpandA_KeccakFIPS204} from "../contracts/verifier/MLDSA65_ExpandA_KeccakFIPS204.sol";

contract MLDSA_ExpandA_KAT_Structure_Test is Test {
    uint256 constant K = 6;
    uint256 constant L = 5;
    uint256 constant Q = 8380417;

    function test_expandA_kat_dummy_structure() public {
        // читаємо dummy JSON, щоб перевірити, що форми/ключі нормальні
        string memory path = string(
            abi.encodePacked(vm.projectRoot(), "/test_vectors/expandA_dummy.json")
        );
        string memory json = vm.readFile(path);

        // базові поля
        string memory name = vm.parseJsonString(json, ".vector.name");
        assertEq(name, "expandA_dummy");

        uint256 k = vm.parseJsonUint(json, ".vector.params.k");
        uint256 l = vm.parseJsonUint(json, ".vector.params.l");
        uint256 q = vm.parseJsonUint(json, ".vector.params.q");

        assertEq(k, K);
        assertEq(l, L);
        assertEq(q, Q);

        // вибірково перевіримо кілька коефіцієнтів
        // A[0][1][0] == 1
        uint256 a010 = vm.parseJsonUint(json, ".vector.A[0][1][0]");
        assertEq(a010, 1);

        // A[5][4][3] == 29
        uint256 a543 = vm.parseJsonUint(json, ".vector.A[5][4][3]");
        assertEq(a543, 29);
    }
}
