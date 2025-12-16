// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MLDSA65_Verifier_v2} from "../contracts/verifier/MLDSA65_Verifier_v2.sol";

contract MLDSA_Verify_POC_Test is Test {
    MLDSA65_Verifier_v2 verifier;

    function setUp() public {
        verifier = new MLDSA65_Verifier_v2();
    }

    /// @dev Мінімальний валідний публічний ключ:
    /// просто 1952 байти нулів (t1 + rho), нас ці значення поки не цікавлять.
    function _makePk() internal pure returns (MLDSA65_Verifier_v2.PublicKey memory pk) {
        bytes memory raw = new bytes(1952); // T1_PACKED_BYTES (1920) + RHO (32)
        pk.raw = raw;
        return pk;
    }

    /// @dev Мінімальна сигнатура:
    ///  - перші 32 байти: z (усі нулі → точно в межах γ₁)
    ///  - останні 32 байти: seed для challenge c.
    function _makeSig(bytes32 cSeed)
        internal
        pure
        returns (MLDSA65_Verifier_v2.Signature memory sig)
    {
        bytes memory sigRaw = abi.encodePacked(bytes32(0), cSeed);
        sig.raw = sigRaw;
        return sig;
    }

    /// @notice Якщо seed у сигнатурі збігається з message_digest,
    /// poly_challenge(dsig.c) == poly_challenge(message_digest),
    /// тому verify() має повернути true.
    function test_verify_accepts_matching_challenge_seed() public {
        MLDSA65_Verifier_v2.PublicKey memory pk = _makePk();

        bytes32 seed = bytes32(uint256(0x01));
        MLDSA65_Verifier_v2.Signature memory sig = _makeSig(seed);

        bool ok = verifier.verify(pk, sig, seed);
        assertTrue(ok, "verify should accept self-consistent challenge");
    }

    /// @notice Якщо seed у сигнатурі та в message_digest різні,
    /// poly_challenge(dsig.c) != poly_challenge(message_digest),
    /// verify() має повернути false.
    function test_verify_rejects_mismatching_challenge_seed() public {
        MLDSA65_Verifier_v2.PublicKey memory pk = _makePk();

        bytes32 seedSig = bytes32(uint256(0x01));
        MLDSA65_Verifier_v2.Signature memory sig = _makeSig(seedSig);

        bytes32 otherSeed = bytes32(uint256(0x02));
        bool ok = verifier.verify(pk, sig, otherSeed);
        assertFalse(ok, "verify must reject mismatching challenge seed");
    }
}
