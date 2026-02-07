// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NTT_MLDSA_Real} from "./NTT_MLDSA_Real.sol";

/// @title ML-DSA-65 NTT (публічний фасад)
/// @notice Тонкий wrapper над реальною NTT-реалізацією.
/// @dev Інші контракти мають імпортувати САМЕ ЦЮ бібліотеку.
library NTT_MLDSA {
    uint256 internal constant Q = 8380417;
    uint256 internal constant N = 256;

    /// @notice Forward NTT (Cooley–Tukey, як у Dilithium/ML-DSA)
    function ntt(uint256[256] memory a) internal pure returns (uint256[256] memory) {
        return NTT_MLDSA_Real.ntt(a);
    }

    /// @notice Inverse NTT (Gentleman–Sande) + множення на N⁻¹ mod q
    function intt(uint256[256] memory a) internal pure returns (uint256[256] memory) {
        return NTT_MLDSA_Real.intt(a);
    }
}
