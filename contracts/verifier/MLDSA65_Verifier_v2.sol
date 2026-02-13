// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Polynomial helpers for ML-DSA-65 over Z_q, q = 8380417 (Dilithium modulus).
library MLDSA65_Poly {
    uint256 internal constant N = 256;
    int32 internal constant Q = 8380417; // fits in int32

    /// @notice r = (a + b) mod q, coefficient-wise
    function add(
        int32[256] memory a,
        int32[256] memory b
    ) internal pure returns (int32[256] memory r) {
        int64 q = int64(Q);
        for (uint256 i = 0; i < N; ++i) {
            int64 tmp = int64(a[i]) + int64(b[i]);
            tmp %= q;
            if (tmp < 0) tmp += q;
            r[i] = int32(tmp);
        }
    }

    /// @notice r = (a - b) mod q, coefficient-wise
    function sub(
        int32[256] memory a,
        int32[256] memory b
    ) internal pure returns (int32[256] memory r) {
        int64 q = int64(Q);
        for (uint256 i = 0; i < N; ++i) {
            int64 tmp = int64(a[i]) - int64(b[i]);
            tmp %= q;
            if (tmp < 0) tmp += q;
            r[i] = int32(tmp);
        }
    }

    /// @notice r = a ∘ b (pointwise) mod q, coefficient-wise multiply
    /// @dev This is a simple reference implementation; later we will replace it
    ///      with Montgomery-based multiplication aligned with the NTT core.
    function pointwiseMul(
        int32[256] memory a,
        int32[256] memory b
    ) internal pure returns (int32[256] memory r) {
        int64 q = int64(Q);
        for (uint256 i = 0; i < N; ++i) {
            int64 tmp = (int64(a[i]) * int64(b[i])) % q;
            if (tmp < 0) tmp += q;
            r[i] = int32(tmp);
        }
    }
}

/// @notice Polynomial vector types and helpers for ML-DSA-65.
/// @dev Parameters match Dilithium3 / ML-DSA-65: k = 6, l = 5.
library MLDSA65_PolyVec {
    uint256 internal constant N = 256;
    uint256 internal constant K = 6; // length of t1 (polyvecK)
    uint256 internal constant L = 5; // length of z, h (polyvecL)

    struct PolyVecL {
        int32[256][L] polys;
    }

    struct PolyVecK {
        int32[256][K] polys;
    }

    /// @notice r = (a + b) mod q, component-wise, for L-length vectors.
    function addL(
        PolyVecL memory a,
        PolyVecL memory b
    ) internal pure returns (PolyVecL memory r) {
        for (uint256 i = 0; i < L; ++i) {
            r.polys[i] = MLDSA65_Poly.add(a.polys[i], b.polys[i]);
        }
    }

    /// @notice r = (a - b) mod q, component-wise, for L-length vectors.
    function subL(
        PolyVecL memory a,
        PolyVecL memory b
    ) internal pure returns (PolyVecL memory r) {
        for (uint256 i = 0; i < L; ++i) {
            r.polys[i] = MLDSA65_Poly.sub(a.polys[i], b.polys[i]);
        }
    }

    /// @notice r = (a + b) mod q, component-wise, for K-length vectors.
    function addK(
        PolyVecK memory a,
        PolyVecK memory b
    ) internal pure returns (PolyVecK memory r) {
        for (uint256 i = 0; i < K; ++i) {
            r.polys[i] = MLDSA65_Poly.add(a.polys[i], b.polys[i]);
        }
    }

    /// @notice r = (a - b) mod q, component-wise, for K-length vectors.
    function subK(
        PolyVecK memory a,
        PolyVecK memory b
    ) internal pure returns (PolyVecK memory r) {
        for (uint256 i = 0; i < K; ++i) {
            r.polys[i] = MLDSA65_Poly.sub(a.polys[i], b.polys[i]);
        }
    }

    /// @notice NTT wrapper for PolyVecL.
    /// @dev TODO: wire to the real NTT core (NTT_MLDSA_Real) later.
    function nttL(
        PolyVecL memory v
    ) internal pure returns (PolyVecL memory r) {
        // Identity placeholder for now.
        return v;
    }

    /// @notice inverse NTT wrapper for PolyVecL.
    function inttL(
        PolyVecL memory v
    ) internal pure returns (PolyVecL memory r) {
        // Identity placeholder for now.
        return v;
    }

    /// @notice NTT wrapper for PolyVecK.
    function nttK(
        PolyVecK memory v
    ) internal pure returns (PolyVecK memory r) {
        // Identity placeholder for now.
        return v;
    }

    /// @notice inverse NTT wrapper for PolyVecK.
    function inttK(
        PolyVecK memory v
    ) internal pure returns (PolyVecK memory r) {
        // Identity placeholder for now.
        return v;
    }
}

/// @notice Hint layer for ML-DSA-65 (high-level structure).
/// @dev Real ML-DSA-65 uses hint bits to reconstruct high bits of w.
///      Here we only define the data structure and basic validation.
library MLDSA65_Hint {
    uint256 internal constant N = 256;
    uint256 internal constant L = 5; // same L as in MLDSA65_PolyVec

    /// @notice Hint for a PolyVecL: for each coefficient we store a small flag.
    /// @dev Typical range is {-1, 0, 1}, but here we only enforce a small bounded range.
    struct HintVecL {
        int8[256][L] flags;
    }

    /// @notice Simple range check for hint flags.
    /// @dev Ensures all flags are in [-1, 1]. This is a sanity check, not the full spec.
    function isValidHint(
        HintVecL memory hint
    ) internal pure returns (bool) {
        for (uint256 i = 0; i < L; ++i) {
            for (uint256 j = 0; j < N; ++j) {
                int8 v = hint.flags[i][j];
                if (v < -1 || v > 1) {
                    return false;
                }
            }
        }
        return true;
    }

    /// @notice Apply hint to w in PolyVecL domain.
    /// @dev For now this is an identity placeholder. Real logic will adjust w
    ///      according to hint flags to reconstruct the high bits.
    function applyHintL(
        MLDSA65_PolyVec.PolyVecL memory w,
        HintVecL memory hint
    ) internal pure returns (MLDSA65_PolyVec.PolyVecL memory r) {
        // Mark parameters as used to avoid warnings.
        hint;
        return w;
    }
}

/// @notice ML-DSA-65 Verifier v2 – skeleton for the real verification pipeline.
/// @dev For now this only fixes ABI and prepares for the polynomial/NTT/hint layers.
contract MLDSA65_Verifier_v2 {
    using MLDSA65_Poly for int32[256];

    uint256 internal constant PK_BYTES = 1952;
    uint256 internal constant SIG_BYTES = 3309;

    struct PublicKey {
        // FIPS-204 encoded ML-DSA-65 public key (1952 bytes)
        bytes raw;
    }

    struct Signature {
        // FIPS-204 encoded ML-DSA-65 signature (3309 bytes)
        bytes raw;
    }

    /// @notice Decoded public key components used by the verifier.
    struct DecodedPublicKey {
        MLDSA65_PolyVec.PolyVecK t1;
        bytes32 rho; // seed for matrix A
    }

    /// @notice Decoded signature components used by the verifier.
    struct DecodedSignature {
        MLDSA65_PolyVec.PolyVecL z;
        MLDSA65_Hint.HintVecL h;
        bytes32 c; // challenge
    }

    /// @notice Decode FIPS-204 encoded ML-DSA-65 public key.
    /// @dev If the encoding length does not match PK_BYTES, a zero-initialized
    ///      structure is returned. Otherwise rho is loaded from the last 32 bytes.
    function _decodePublicKey(
        bytes memory raw
    ) internal pure returns (DecodedPublicKey memory pkDec) {
        if (raw.length != PK_BYTES) {
            return pkDec;
        }

        bytes32 rho;
        uint256 len = raw.length;
        assembly {
            rho := mload(add(add(raw, 32), sub(len, 32)))
        }
        pkDec.rho = rho;

        // TODO: implement decoding of t1 from raw.
        return pkDec;
    }

    /// @notice Decode FIPS-204 encoded ML-DSA-65 signature.
    /// @dev If the encoding length does not match SIG_BYTES, a zero-initialized
    ///      structure is returned. Otherwise c is loaded from the last 32 bytes.
    function _decodeSignature(
        bytes memory raw
    ) internal pure returns (DecodedSignature memory sigDec) {
        if (raw.length != SIG_BYTES) {
            return sigDec;
        }

        bytes32 c;
        uint256 len = raw.length;
        assembly {
            c := mload(add(add(raw, 32), sub(len, 32)))
        }
        sigDec.c = c;

        // TODO: implement decoding of z and h from raw.
        return sigDec;
    }

    /// @notice Compute w = A * z - c * t1 in polynomial domain.
    /// @dev Placeholder wiring for the matrix pipeline. Real implementation
    ///      will use NTT, polynomial operations and hint layer.
    function _compute_w(
        DecodedPublicKey memory pkDec,
        DecodedSignature memory sigDec,
        bytes32 messageDigest
    ) internal pure returns (MLDSA65_PolyVec.PolyVecK memory w) {
        // Mark unused parameters to avoid warnings for now.
        messageDigest;
        sigDec.h;

        // Structural placeholder: start from t1.
        w = pkDec.t1;
    }

    /// @notice Main verification entrypoint (not implemented yet).
    function verify(
        PublicKey memory pk,
        Signature memory sig,
        bytes32 message_digest
    ) external pure returns (bool) {
        DecodedPublicKey memory pkDec = _decodePublicKey(pk.raw);
        DecodedSignature memory sigDec = _decodeSignature(sig.raw);

        MLDSA65_PolyVec.PolyVecK memory w =
            _compute_w(pkDec, sigDec, message_digest);

        // Mark variable as used to avoid warnings.
        w;

        // TODO:
        // 1) Implement real decoding for pk and sig.
        // 2) Implement matrix pipeline A * z - c * t1.
        // 3) Decompose w, apply hint and recompute challenge hash.
        // 4) Compare against sigDec.c and return true/false.

        return false;
    }
}

