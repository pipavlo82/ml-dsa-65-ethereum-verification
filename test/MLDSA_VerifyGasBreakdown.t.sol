// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// Named imports: беремо і контракт, і бібліотеку типів.
import {MLDSA65_Verifier_v2, MLDSA65_PolyVec} from "../contracts/verifier/MLDSA65_Verifier_v2.sol";

/// @notice Expose internal-only helpers of MLDSA65_Verifier_v2 for gas breakdown tests.
contract MLDSA65_Verifier_v2_Expose is MLDSA65_Verifier_v2 {
    function ex_decodePublicKey(bytes memory pkRaw)
        external
        pure
        returns (DecodedPublicKey memory dpk)
    {
        return _decodePublicKey(pkRaw);
    }

    function ex_decodeSignature(bytes memory sigRaw)
        external
        pure
        returns (DecodedSignature memory dsig)
    {
        return _decodeSignature(sigRaw);
    }

    function ex_compute_w(DecodedPublicKey memory dpk, DecodedSignature memory dsig)
        external
        pure
        returns (MLDSA65_PolyVec.PolyVecK memory w)
    {
        return _compute_w(dpk, dsig);
    }

    function ex_checkZNormGamma1Bound(DecodedSignature memory dsig)
        external
        pure
        returns (bool ok)
    {
        return _checkZNormGamma1Bound(dsig);
    }
}

/// @notice Gas breakdown harness for ML-DSA-65 verifier v2 (decode + compute_w).
/// @dev Not a correctness/KAT test. Uses shape-correct zeroed inputs for stable gas.
contract MLDSA_VerifyGasBreakdown_Test is Test {
    uint256 internal constant PK_LEN = 1952;
    uint256 internal constant SIG_LEN = 3309;

    MLDSA65_Verifier_v2_Expose internal v;

    function setUp() public {
        v = new MLDSA65_Verifier_v2_Expose();
    }

    function _zeroBytes(uint256 n) internal pure returns (bytes memory out) {
        out = new bytes(n);
    }

    function test_breakdown_decode_and_compute_w() public {
        bytes memory pk = _zeroBytes(PK_LEN);
        bytes memory sig = _zeroBytes(SIG_LEN);

        uint256 g0;

        // decode(pk)
        g0 = gasleft();
        MLDSA65_Verifier_v2.DecodedPublicKey memory dpk = v.ex_decodePublicKey(pk);
        uint256 gas_decode_pk = g0 - gasleft();

        // decode(sig)
        g0 = gasleft();
        MLDSA65_Verifier_v2.DecodedSignature memory dsig = v.ex_decodeSignature(sig);
        uint256 gas_decode_sig = g0 - gasleft();

        // z-norm bound check
        g0 = gasleft();
        bool z_ok = v.ex_checkZNormGamma1Bound(dsig);
        uint256 gas_check_z = g0 - gasleft();

        // compute w = A*z - c*t1
        g0 = gasleft();
        MLDSA65_PolyVec.PolyVecK memory w = v.ex_compute_w(dpk, dsig);
        uint256 gas_compute_w = g0 - gasleft();

        // Touch vars
        w;
        assertTrue(z_ok == true || z_ok == false);

        emit log_named_uint("gas_decode_pk", gas_decode_pk);
        emit log_named_uint("gas_decode_sig", gas_decode_sig);
        emit log_named_uint("gas_check_z_norm", gas_check_z);
        emit log_named_uint("gas_compute_w(A*z-c*t1)", gas_compute_w);
        emit log_named_uint(
            "gas_total_decode+check+compute_w",
            gas_decode_pk + gas_decode_sig + gas_check_z + gas_compute_w
        );
    }

    function test_shape_lengths() public pure {
        assertEq(PK_LEN, 1952);
        assertEq(SIG_LEN, 3309);
    }
}
