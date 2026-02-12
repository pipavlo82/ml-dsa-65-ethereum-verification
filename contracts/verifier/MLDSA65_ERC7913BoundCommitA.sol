// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MLDSA65_ERC7913Verifier.sol";
import "../interfaces/IERC7913SignatureVerifier.sol";
import "./MLDSA65_Verifier_v2.sol";

/// @notice ERC-7913 verifier + binding commitA через pkH = keccak256(pubkey_raw)
contract MLDSA65_ERC7913BoundCommitA is MLDSA65_ERC7913Verifier {
    /// @dev pkH -> commitA (наприклад keccak256(packedA_ntt) або інший commitment)
    mapping(bytes32 => bytes32) public commitAOf;

    error CommitA_Mismatch();
    error CommitA_NotSet();

    /// @notice Запис binding напряму (коли вже маєш pkH)
    function setCommitA(bytes32 pkH, bytes32 commitA) external {
        commitAOf[pkH] = commitA;
    }

    /// @notice Зручний хелпер для тестів: передаєш pubkey raw, ми рахуємо pkH
    function registerCommitA(bytes calldata key, bytes32 commitA) external {
        commitAOf[keccak256(key)] = commitA;
    }

    /// @notice Verify з binding (як у тесті): (pubkey, sig, msgHash, commitA)
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

        // ERC-7913 verify logic (скопійовано з базового адаптера без external-call)
        MLDSA65_Verifier_v2.PublicKey memory pk;
        pk.raw = key;

        MLDSA65_Verifier_v2.Signature memory sig;
        sig.raw = signature;

        bool ok = verifier.verify(pk, sig, hash);

        if (!ok) return 0xffffffff;
        return IERC7913SignatureVerifier.verify.selector;
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
}
