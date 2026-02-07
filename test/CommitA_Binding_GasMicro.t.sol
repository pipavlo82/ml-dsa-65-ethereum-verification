// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_ERC7913BoundCommitA.sol";

contract CommitA_Binding_GasMicro_Test is Test {
    MLDSA65_ERC7913BoundCommitA v;

    bytes constant PUBKEY = hex"010203";
    bytes constant SIG    = hex"040506";
    bytes32 constant MSGH = keccak256("m");

    function setUp() public {
        v = new MLDSA65_ERC7913BoundCommitA();
    }

    function test_gas_setCommitA() public {
        bytes32 pkH = keccak256(PUBKEY);
        bytes32 commitA = keccak256("A");

        uint256 g0 = gasleft();
        v.setCommitA(pkH, commitA);
        uint256 used = g0 - gasleft();

        emit log_named_uint("gas_setCommitA(SSTORE new slot)", used);
    }

    function test_gas_verifyBound_mismatch_only() public {
        bytes32 pkH = keccak256(PUBKEY);
        bytes32 good = keccak256("A");
        bytes32 bad  = keccak256("B");

        v.setCommitA(pkH, good);

        uint256 g0 = gasleft();
        vm.expectRevert(MLDSA65_ERC7913BoundCommitA.CommitA_Mismatch.selector);
        v.verifyBound(PUBKEY, SIG, MSGH, bad);
        uint256 used = g0 - gasleft();

        emit log_named_uint("gas_verifyBound(mismatch revert path)", used);
    }
}
