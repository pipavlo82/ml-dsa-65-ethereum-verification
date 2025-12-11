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

/// @notice Hint vector helpers for ML-DSA-65.
library MLDSA65_Hint {
    uint256 internal constant N = 256;
    uint256 internal constant L = 5; // hint lives in the same L-dimension

    /// @notice Hint vector: flags in {-1, 0, 1} per coefficient.
    struct HintVecL {
        int8[256][L] flags;
    }

    /// @notice Basic sanity check: all flags must be in {-1, 0, 1}.
    function isValidHint(HintVecL memory h) internal pure returns (bool) {
        for (uint256 j = 0; j < L; ++j) {
            for (uint256 i = 0; i < N; ++i) {
                int8 v = h.flags[j][i];
                if (v < -1 || v > 1) {
                    return false;
                }
            }
        }
        return true;
    }

    /// @notice Placeholder applyHint for PolyVecL.
    /// @dev For now this acts as an identity mapping; real behavior will be
    ///      filled in once the full decomposition / hint logic is wired.
    function applyHintL(
        MLDSA65_PolyVec.PolyVecL memory w,
        HintVecL memory /*h*/
    ) internal pure returns (MLDSA65_PolyVec.PolyVecL memory out) {
        return w;
    }
}

/// @notice ML-DSA-65 Verifier v2 – skeleton for the real verification pipeline.
/// @dev For now this fixes the ABI, decode layer, and prepares for the polynomial/NTT layer.
contract MLDSA65_Verifier_v2 {
    using MLDSA65_Poly for int32[256];

    int32 internal constant Q = 8380417;

    struct PublicKey {
        // FIPS-204 encoded ML-DSA-65 public key (1952 bytes)
        bytes raw;
    }

    struct Signature {
        // FIPS-204 encoded ML-DSA-65 signature (3309 bytes)
        bytes raw;
    }

    struct DecodedPublicKey {
        bytes32 rho;
        MLDSA65_PolyVec.PolyVecK t1;
    }

    struct DecodedSignature {
        bytes32 c;
        MLDSA65_PolyVec.PolyVecL z;
        MLDSA65_Hint.HintVecL h;
    }

    /// @notice Main verification entrypoint (not implemented yet).
    function verify(
        PublicKey memory pk,
        Signature memory sig,
        bytes32 message_digest
    ) external pure returns (bool) {
        // length guards: we at least expect to be able to read rho and c
        if (pk.raw.length < 32 || sig.raw.length < 32) {
            return false;
        }

        DecodedPublicKey memory dpk = _decodePublicKey(pk.raw);
        DecodedSignature memory dsig = _decodeSignature(sig.raw);

        // Keep the pipeline wired structurally: compute w and apply hint later.
        MLDSA65_PolyVec.PolyVecK memory w = _compute_w(dpk, dsig);
        w;
        message_digest; // will be used in real hash check

        // Full ML-DSA-65 verification is not implemented yet.
        return false;
    }

    /// @notice Decode public key bytes into a structured view.
    /// @dev Current behavior:
    ///  - rho is taken from the last 32 bytes of pkRaw
    ///  - first few coefficients of t1[0] are decoded from the beginning of pkRaw
    function _decodePublicKey(
        bytes memory pkRaw
    ) internal pure returns (DecodedPublicKey memory dpk) {
        uint256 len = pkRaw.length;

        // 1) rho from the last 32 bytes (if present)
        if (len >= 32) {
            uint256 off = len - 32;
            bytes32 rhoBytes;
            assembly {
                rhoBytes := mload(add(add(pkRaw, 0x20), off))
            }
            dpk.rho = rhoBytes;
        }

        // 2) synthetic packing for a few leading coefficients of t1[0]
        //    This uses a simple 4-bytes-per-coefficient LE layout and is
        //    intended to be replaced by real FIPS-204 packing later.
        uint256 maxCoeffs = 4;
        for (uint256 i = 0; i < maxCoeffs; ++i) {
            uint256 off = i * 4;
            if (off + 4 > len) {
                break;
            }
            int32 coeff = _decodeCoeffLE(pkRaw, off);
            dpk.t1.polys[0][i] = coeff;
        }
    }

    /// @notice Decode signature bytes into a structured view.
    /// @dev Current behavior:
    ///  - c is taken from the last 32 bytes of sigRaw
    ///  - first few coefficients of z[0] are decoded from the beginning of sigRaw
    function _decodeSignature(
        bytes memory sigRaw
    ) internal pure returns (DecodedSignature memory dsig) {
        uint256 len = sigRaw.length;

        // 1) c from the last 32 bytes (if present)
        if (len >= 32) {
            uint256 off = len - 32;
            bytes32 cBytes;
            assembly {
                cBytes := mload(add(add(sigRaw, 0x20), off))
            }
            dsig.c = cBytes;
        }

        // 2) synthetic packing for a few leading coefficients of z[0]
        uint256 maxCoeffs = 4;
        for (uint256 i = 0; i < maxCoeffs; ++i) {
            uint256 off = i * 4;
            if (off + 4 > len) {
                break;
            }
            int32 coeff = _decodeCoeffLE(sigRaw, off);
            dsig.z.polys[0][i] = coeff;
        }

        // h remains zeroed for now; real hint packing will be added later.
    }

    /// @notice Decode a single coefficient from 4 bytes in little-endian order, reduced mod Q.
    /// @dev This is a low-level helper for early prototyping and will be reused
    ///      when wiring the real FIPS-204 packing.
    function _decodeCoeffLE(
        bytes memory src,
        uint256 offset
    ) internal pure returns (int32) {
        require(offset + 4 <= src.length, "coeff decode out of bounds");

        uint32 v =
            uint32(uint8(src[offset])) |
            (uint32(uint8(src[offset + 1])) << 8) |
            (uint32(uint8(src[offset + 2])) << 16) |
            (uint32(uint8(src[offset + 3])) << 24);

        uint32 q = uint32(uint32(uint32(uint32(int32(Q)))));
        uint32 reduced = v % q;
        return int32(int256(uint256(reduced)));
    }

    /// @notice Structural placeholder for w = A * z - c * t1 in ML-DSA-65.
    /// @dev For now this simply forwards t1 as w so that the pipeline is wired
    ///      and tests can exercise the decoded structures.
    function _compute_w(
        DecodedPublicKey memory dpk,
        DecodedSignature memory dsig
    ) internal pure returns (MLDSA65_PolyVec.PolyVecK memory w) {
        // Use t1 as a structural stand-in for w.
        w = dpk.t1;

        // Touch dsig fields to avoid unused-variable warnings.
        dsig.c;
        dsig.z;
        dsig.h;

        return w;
    }
}
