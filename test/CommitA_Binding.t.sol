// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { MLDSA65_ERC7913BoundCommitA } from "../contracts/verifier/MLDSA65_ERC7913BoundCommitA.sol";

contract CommitA_Binding_Test is Test {
    MLDSA65_ERC7913BoundCommitA v;

    function setUp() public {
        v = new MLDSA65_ERC7913BoundCommitA();
    }

    function test_commitA_binding_reverts_on_mismatch() public {
        bytes memory pubkey = hex"010203"; // dummy
        bytes memory sig = hex"04";        // dummy
        bytes32 msgHash = keccak256("m");

        bytes32 good = keccak256("good");
        bytes32 bad  = keccak256("bad");

        v.registerCommitA(pubkey, good);

        vm.expectRevert(MLDSA65_ERC7913BoundCommitA.CommitA_Mismatch.selector);
        v.verifyBound(pubkey, sig, msgHash, bad);
    }

    function test_commitA_binding_allows_match() public {
        bytes memory pubkey = hex"010203"; // dummy
        bytes memory sig = hex"04";        // dummy
        bytes32 msgHash = keccak256("m");

        bytes32 good = keccak256("good");
        v.registerCommitA(pubkey, good);

        // Ми не очікуємо PASS/FAIL криптографічно (бо dummy дані),
        // тут перевіряємо тільки що binding не revert'ить.
        v.verifyBound(pubkey, sig, msgHash, good);
    }
}
