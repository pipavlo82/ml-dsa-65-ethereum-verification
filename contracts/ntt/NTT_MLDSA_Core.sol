// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./NTT_MLDSA_Zetas.sol";

/// @title ML-DSA-65 NTT core (placeholder)
/// @notice Сюди пізніше зайде справжній Cooley–Tukey 256-point NTT.
///         Зараз це просто каркас, який нічого не ламає.

library NTT_MLDSA_Core {
    uint256 internal constant Q = 8380417;
    uint256 internal constant N = 256;

    // Справжня NTT буде тут
    function ntt(uint256[256] memory a)
        internal
        pure
        returns (uint256[256] memory)
    {
        // TODO: Реальна реалізація Cooley–Tukey зайде сюди
        return a;
    }

    // Inverse NTT (Gentleman–Sande) буде тут
    function intt(uint256[256] memory a)
        internal
        pure
        returns (uint256[256] memory)
    {
        // TODO: Реальна реалізація inverse NTT тут
        return a;
    }
}
