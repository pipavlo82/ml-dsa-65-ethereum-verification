// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IPQVerifier.sol";

contract MLDSA65Verifier is IPQVerifier {
    function verify(
        bytes32,
        bytes calldata,
        bytes calldata
    ) external pure override returns (bool ok) {
        return false;
    }
}
