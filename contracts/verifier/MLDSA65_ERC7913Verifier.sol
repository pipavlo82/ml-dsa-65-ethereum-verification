// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IERC7913SignatureVerifier.sol";
import "./MLDSA65_Verifier_v2.sol";

/// @title ML-DSA-65 ERC-7913-compatible signature verifier
/// @notice Адаптер, який обгортає MLDSA65_Verifier_v2 в стандарт ERC-7913.
/// @dev verify(...) лишається 100% IERC7913-совісним. Додаткові entrypoints — це overload-и.
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
        // Обгортаємо raw bytes в наші внутрішні структури
        MLDSA65_Verifier_v2.PublicKey memory pk;
        pk.raw = key;

        MLDSA65_Verifier_v2.Signature memory sig;
        sig.raw = signature;

        bool ok = verifier.verify(pk, sig, hash);

        // ERC-7913 рекомендує або revert, або "failure code". У тебе вже прийнято 0xffffffff.
        if (!ok) return bytes4(0xffffffff);
        return IERC7913SignatureVerifier.verify.selector;
    }

    /// @notice Verify using packedA_ntt from calldata (skips on-chain ExpandA).
    /// @dev Повертає verify.selector при success, і 0xffffffff при failure.
    function verifyWithPackedA(
        bytes calldata key,
        bytes32 hash,
        bytes calldata signature,
        bytes calldata packedA_ntt
    ) external view returns (bytes4) {
        bool ok = _callOkPackedA(hash, signature, key, packedA_ntt);
        if (!ok) return bytes4(0xffffffff);
        return IERC7913SignatureVerifier.verify.selector;
    }

    // -----------------------
    // Internal helpers
    // -----------------------

    /// @dev Robust decode: працює і якщо verifier повертає bool, і якщо uint256 ok_flag.
    function _callOkPackedA(
        bytes32 hash,
        bytes calldata signature,
        bytes calldata key,
        bytes calldata packedA_ntt
    ) internal view returns (bool) {
        (bool success, bytes memory ret) = address(verifier).staticcall(
            abi.encodeWithSignature(
                "verifyWithPackedA(bytes32,bytes,bytes,bytes)",
                hash,
                signature,
                key,
                packedA_ntt
            )
        );
        if (!success || ret.length < 32) return false;

        uint256 v = abi.decode(ret, (uint256));
        return v == 1;
    }
}
