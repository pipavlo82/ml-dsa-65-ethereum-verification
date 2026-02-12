// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/zknox_keccak/MLDSA65_KeccakXOF.sol";

contract MLDSA_KeccakXOF_Smoke_Test is Test {
    using MLDSA65_KeccakXOF for MLDSA65_KeccakXOF.Stream;

    function test_expandA_stream_deterministic() public {
        bytes32 rho = keccak256("rho-example");
        uint16 row = 3;
        uint16 col = 5;

        MLDSA65_KeccakXOF.Stream memory s1 = MLDSA65_KeccakXOF.initExpandA(rho, row, col);
        MLDSA65_KeccakXOF.Stream memory s2 = MLDSA65_KeccakXOF.initExpandA(rho, row, col);

        uint16[4] memory seq1;
        uint16[4] memory seq2;

        for (uint256 i = 0; i < 4; i++) {
            seq1[i] = s1.nextU16();
            seq2[i] = s2.nextU16();
        }

        // Детермінізм: однакові вхідні параметри → однакова послідовність.
        assertEq(seq1[0], seq2[0], "u16[0] mismatch");
        assertEq(seq1[1], seq2[1], "u16[1] mismatch");
        assertEq(seq1[2], seq2[2], "u16[2] mismatch");
        assertEq(seq1[3], seq2[3], "u16[3] mismatch");
    }

    function test_expandA_stream_changes_with_row_col() public {
        bytes32 rho = keccak256("rho-example");

        MLDSA65_KeccakXOF.Stream memory s_row3 = MLDSA65_KeccakXOF.initExpandA(rho, 3, 5);
        MLDSA65_KeccakXOF.Stream memory s_row4 = MLDSA65_KeccakXOF.initExpandA(rho, 4, 5);

        uint16 v1 = s_row3.nextU16();
        uint16 v2 = s_row4.nextU16();

        // Інший (row,col) → інший XOF-потік з великою ймовірністю.
        // Це sanity-check, а не крипто-доведення.
        assertTrue(v1 != v2, "row change should affect stream");
    }
}
