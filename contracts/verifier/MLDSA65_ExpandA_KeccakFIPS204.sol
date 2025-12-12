// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../zknox_keccak/ZKNox_KeccakPRNG.sol";

library MLDSA65_ExpandA_KeccakFIPS204 {
    uint32 internal constant Q = 8380417;
    uint8 internal constant L = 5;
    uint8 internal constant K = 6;
    uint16 internal constant N = 256;

    error ExpandA_InvalidRow();
    error ExpandA_InvalidCol();

    /// @notice Keccak-based прототип ExpandA_poly: один поліном A[row][col]
    /// @dev Реалізований напряму через ZKNox Keccak PRNG (ETHDILITHIUM backend).
    function expandA_poly(
        bytes32 rho,
        uint8 row,
        uint8 col
    ) internal pure returns (int32[256] memory a) {
        if (row >= L) revert ExpandA_InvalidRow();
        if (col >= K) revert ExpandA_InvalidCol();

        // domain separation: rho || row || col
        bytes memory input = abi.encodePacked(rho, row, col);
        KeccakPRNG memory prng = initPRNG(input);

        for (uint16 i = 0; i < N; ) {
            // 4 байти → 32-бітне слово
            uint32 v =
                uint32(nextByte(prng)) |
                (uint32(nextByte(prng)) << 8) |
                (uint32(nextByte(prng)) << 16) |
                (uint32(nextByte(prng)) << 24);

            uint32 coeff = v % Q;
            a[i] = int32(coeff);

            unchecked {
                ++i;
            }
        }
    }
}
