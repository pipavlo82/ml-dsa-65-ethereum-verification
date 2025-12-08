// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../ntt/NTT_MLDSA.sol";
import "../ntt/NTT_MLDSA_Zetas_New.sol";

contract MLDSA65_Verifier {
    uint256 constant Q = 8380417;

    struct PublicKey {
        uint256[256] t1;
    }

    struct Signature {
        uint256[256] z;
        uint256[256] c;
        uint8[256] hint;
    }

    function verify(
        PublicKey memory pk,
        Signature memory sig,
        bytes32 message_digest
    ) public view returns (bool) {

        // TODO: decode and validate signature bounds
        // TODO: compute w = A*z - c*t1
        // TODO: NTT roundtrip of z and t1
        // TODO: compute challenge' from Keccak/SHAKE
        // TODO: compare challenge' == sig.c

        return true; // placeholder
    }
}
