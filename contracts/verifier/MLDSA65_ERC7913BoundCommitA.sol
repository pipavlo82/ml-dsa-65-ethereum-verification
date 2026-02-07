// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MLDSA65_ERC7913Verifier.sol";
import "../interfaces/IERC7913SignatureVerifier.sol";

/// @notice ERC-7913 verifier + binding commitA через pkH = keccak256(pubkey_raw)
contract MLDSA65_ERC7913BoundCommitA is MLDSA65_ERC7913Verifier {
    /// @dev pkH -> commitA (наприклад keccak256(packedA_ntt) або інший commitment)
    mapping(bytes32 => bytes32) public commitAOf;

    error CommitA_Mismatch();
    error CommitA_NotSet();

    function setCommitA(bytes32 pkH, bytes32 commitA) external {
        commitAOf[pkH] = commitA;
    }

    function registerCommitA(bytes calldata key, bytes32 commitA) external {
        commitAOf[keccak256(key)] = commitA;
    }

    function verifyBound(
        bytes calldata key,
        bytes calldata signature,
        bytes32 hash,
        bytes32 commitA
    ) external view returns (bytes4) {
        bytes32 pkH = keccak256(key);

        bytes32 expected = commitAOf[pkH];
        if (expected == bytes32(0)) revert CommitA_NotSet();
        if (commitA != expected) revert CommitA_Mismatch();

        return this.verify(key, hash, signature);
    }

    /// @notice Overload verify з commitA (не ламає IERC7913, бо базовий verify(3 args) лишається)
    function verify(
        bytes calldata key,
        bytes32 hash,
        bytes calldata signature,
        bytes32 commitA
    ) external view returns (bytes4) {
        return this.verifyBound(key, signature, hash, commitA);
    }

    /// @notice CommitA-bound verify using packedA_ntt from calldata (skips on-chain ExpandA).
    function verifyWithPackedA(
        bytes calldata key,
        bytes32 hash,
        bytes calldata signature,
        bytes32 commitA,
        bytes calldata packedA_ntt
    ) external view returns (bytes4) {
        bytes32 pkH = keccak256(key);

        bytes32 expected = commitAOf[pkH];
        if (expected == bytes32(0)) revert CommitA_NotSet();
        if (commitA != expected) revert CommitA_Mismatch();

        bool ok = _callOkPackedA(hash, signature, key, packedA_ntt);
        if (!ok) return bytes4(0xffffffff);
        return IERC7913SignatureVerifier.verify.selector;
    }
}
