// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ERC-7913 Signature Verifier Interface
/// @notice Стандартний інтерфейс із EIP-7913 для універсальних сигнатурних веріфаєрів.
interface IERC7913SignatureVerifier {
    /// @dev Verifies `signature` as a valid signature of `hash` by `key`.
    /// MUST return IERC7913SignatureVerifier.verify.selector on success,
    /// SHOULD return 0xffffffff or revert on failure.
    function verify(bytes calldata key, bytes32 hash, bytes calldata signature)
        external
        view
        returns (bytes4);
}
