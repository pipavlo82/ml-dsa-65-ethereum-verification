// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IERC7913SignatureVerifier.sol";
import "./MLDSA65_Verifier_v2.sol";

/// @title ML-DSA-65 ERC-7913-compatible signature verifier
/// @notice Адаптер, який обгортає MLDSA65_Verifier_v2 в стандарт ERC-7913.
contract MLDSA65_ERC7913Verifier is IERC7913SignatureVerifier {
    MLDSA65_Verifier_v2 public immutable verifier;

    constructor() {
        verifier = new MLDSA65_Verifier_v2();
    }

    /// @inheritdoc IERC7913SignatureVerifier
    function verify(bytes calldata key, bytes32 hash, bytes calldata signature)
        public
        view
        override
        returns (bytes4)
    {
        // Обгортаємо в наші внутрішні структури
        MLDSA65_Verifier_v2.PublicKey memory pk;
        pk.raw = key;

        MLDSA65_Verifier_v2.Signature memory sig;
        sig.raw = signature;

        bool ok = verifier.verify(pk, sig, hash);

        if (!ok) {
            // Стандарт ERC-7913 рекомендує або revert, або 0xffffffff
            return 0xffffffff;
        }

        // Успішна перевірка → повертаємо свій selector
        return IERC7913SignatureVerifier.verify.selector;
    }
}

