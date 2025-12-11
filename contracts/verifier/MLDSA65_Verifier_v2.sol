// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NTT_MLDSA_Real} from "../ntt/NTT_MLDSA_Real.sol";
import {MLDSA65_ExpandA} from "./MLDSA65_ExpandA.sol";
import {MLDSA65_Challenge} from "./MLDSA65_Challenge.sol";

//
// =============================
//  Polynomial core (single poly)
// =============================
//

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
    /// @dev Simple reference implementation; later can be replaced by Montgomery-friendly version.
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

//
// =============================
// PolyVecL / PolyVecK wrappers
// =============================
//

/// @notice Polynomial vector types and helpers for ML-DSA-65.
/// @dev Parameters match Dilithium3 / ML-DSA-65: k = 6, l = 5.
library MLDSA65_PolyVec {
    uint256 internal constant N = 256;
    uint256 internal constant K = 6; // length of t1 (polyvecK)
    uint256 internal constant L = 5; // length of z, h (polyvecL)
    int32 internal constant Q = 8380417;

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

    // -----------------------------
    //  Bridges int32[256] <-> uint256[256]
    // -----------------------------

    function _toNTTDomain(
        int32[256] memory a
    ) internal pure returns (uint256[256] memory r) {
        int256 q = int256(int32(Q));
        for (uint256 i = 0; i < N; ++i) {
            int256 v = int256(a[i]);
            if (v < 0) {
                v %= q;
                if (v < 0) v += q;
            }
            r[i] = uint256(v);
        }
    }

    function _fromNTTDomain(
        uint256[256] memory a
    ) internal pure returns (int32[256] memory r) {
        uint256 q = uint256(uint32(uint32(int32(Q))));
        for (uint256 i = 0; i < N; ++i) {
            uint256 v = a[i] % q;
            r[i] = int32(int256(v));
        }
    }

    function _nttPoly(
        int32[256] memory a
    ) internal pure returns (int32[256] memory r) {
        uint256[256] memory tmp = _toNTTDomain(a);
        tmp = NTT_MLDSA_Real.ntt(tmp);
        r = _fromNTTDomain(tmp);
    }

    function _inttPoly(
        int32[256] memory a
    ) internal pure returns (int32[256] memory r) {
        uint256[256] memory tmp = _toNTTDomain(a);
        tmp = NTT_MLDSA_Real.intt(tmp);
        r = _fromNTTDomain(tmp);
    }

    /// @notice NTT wrapper for PolyVecL.
    function nttL(
        PolyVecL memory v
    ) internal pure returns (PolyVecL memory r) {
        for (uint256 j = 0; j < L; ++j) {
            r.polys[j] = _nttPoly(v.polys[j]);
        }
    }

    /// @notice inverse NTT wrapper for PolyVecL.
    function inttL(
        PolyVecL memory v
    ) internal pure returns (PolyVecL memory r) {
        for (uint256 j = 0; j < L; ++j) {
            r.polys[j] = _inttPoly(v.polys[j]);
        }
    }

    /// @notice NTT wrapper for PolyVecK.
    function nttK(
        PolyVecK memory v
    ) internal pure returns (PolyVecK memory r) {
        for (uint256 k = 0; k < K; ++k) {
            r.polys[k] = _nttPoly(v.polys[k]);
        }
    }

    /// @notice inverse NTT wrapper for PolyVecK.
    function inttK(
        PolyVecK memory v
    ) internal pure returns (PolyVecK memory r) {
        for (uint256 k = 0; k < K; ++k) {
            r.polys[k] = _inttPoly(v.polys[k]);
        }
    }
}

//
// ============
// Hint layer
// ============
//

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
    /// @dev Currently identity; real logic will be added together with full decomposition.
    function applyHintL(
        MLDSA65_PolyVec.PolyVecL memory w,
        HintVecL memory /*h*/
    ) internal pure returns (MLDSA65_PolyVec.PolyVecL memory out) {
        return w;
    }
}

//
// ===================
// Verifier skeleton
// ===================
//

/// @notice ML-DSA-65 Verifier v2 – skeleton for the real verification pipeline.
/// @dev Currently contains: ABI, decode layer, synthetic ExpandA, and w = A·z - c·t1 with a synthetic challenge.
///      Full FIPS-204 decomposition/hints are explicitly out-of-scope for this version.
contract MLDSA65_Verifier_v2 {
    using MLDSA65_Poly for int32[256];

    int32 internal constant Q = 8380417;

    // ============================
    // Public key layout constants
    // ============================

    // t1: K=6 polys, N=256, 10 bits per coeff → 6 * 256 * 10 / 8 = 1920 bytes
    uint256 internal constant T1_PACKED_BYTES = 1920;
    uint256 internal constant RHO_BYTES = 32;
    uint256 internal constant PK_MIN_LEN = T1_PACKED_BYTES + RHO_BYTES; // 1952 bytes

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

    /// @notice Main verification entrypoint with basic structural checks.
    /// @dev This is NOT yet a full FIPS-204 verifier. Currently performs:
    ///      - Structural validation (lengths, c != 0, loose z norm)
    ///      - Computes w = A·z - c·t1 using synthetic ExpandA and challenge
    ///      TODO: Add FIPS-204 compliant decomposition, hints, and final challenge comparison.
    function verify(
        PublicKey memory pk,
        Signature memory sig,
        bytes32 message_digest
    ) external pure returns (bool) {
        // Very basic structural sanity checks.
        if (pk.raw.length < 32 || sig.raw.length < 32) {
            return false;
        }

        DecodedPublicKey memory dpk = _decodePublicKey(pk);
        DecodedSignature memory dsig = _decodeSignature(sig);

        // 1) Challenge must be non-zero (real ML-DSA never uses c = 0).
        if (dsig.c == bytes32(0)) {
            return false;
        }

        // 2) z must have coefficients within a loose bound.
        //    This is a POC check, not the final FIPS-204 gamma1-based norm check.
        if (!_checkZNormLoose(dsig)) {
            return false;
        }

        // 3) Compute w = A*z - c*t1 (synthetic, uses keccak-based challenge and synthetic ExpandA).
        MLDSA65_PolyVec.PolyVecK memory w = _compute_w(dpk, dsig);
        w;
        message_digest;

        // TODO: hook w, message_digest and public key into full FIPS-204 verify.
        // For now we accept signatures that pass basic shape checks.
        return true;
    }

    //
    // Decode helpers – overloads for test compatibility
    //

    /// @notice Decode public key from struct wrapper.
    function _decodePublicKey(
        PublicKey memory pk
    ) internal pure returns (DecodedPublicKey memory dpk) {
        return _decodePublicKeyRaw(pk.raw);
    }

    /// @notice Decode public key directly from raw bytes (for old harnesses).
    function _decodePublicKey(
        bytes memory pkRaw
    ) internal pure returns (DecodedPublicKey memory dpk) {
        return _decodePublicKeyRaw(pkRaw);
    }

    /// @notice Decode signature from struct wrapper.
    function _decodeSignature(
        Signature memory sig
    ) internal pure returns (DecodedSignature memory dsig) {
        return _decodeSignatureRaw(sig.raw);
    }

    /// @notice Decode signature directly from raw bytes (for old harnesses).
    function _decodeSignature(
        bytes memory sigRaw
    ) internal pure returns (DecodedSignature memory dsig) {
        return _decodeSignatureRaw(sigRaw);
    }

    //
    // Real decode logic (Raw)
    //

    /// @notice Decode public key bytes into a structured view.
    /// @dev Two modes:
    /// - len >= PK_MIN_LEN (1952): full FIPS unpack t1 + rho (new path)
    /// - len < PK_MIN_LEN: legacy mode (only rho + first 4 coeff t1[0] from offset 32)
    function _decodePublicKeyRaw(
        bytes memory pkRaw
    ) internal pure returns (DecodedPublicKey memory dpk) {
        uint256 len = pkRaw.length;

        // 1) New FIPS mode: full t1 + rho
        if (len >= PK_MIN_LEN) {
            // rho = last 32 bytes
            uint256 rhoOffset = len - RHO_BYTES;
            bytes32 rhoBytes;
            assembly {
                rhoBytes := mload(add(add(pkRaw, 0x20), rhoOffset))
            }
            dpk.rho = rhoBytes;

            // t1: first 1920 bytes (packed 10-bit coefficients)
            _decodeT1Packed(pkRaw, dpk.t1);
            return dpk;
        }

        // 2) Legacy mode (old Decode* tests expect this behaviour).

        // rho = last 32 bytes, if available
        if (len >= 32) {
            uint256 off = len - 32;
            bytes32 rhoLegacy;
            assembly {
                rhoLegacy := mload(add(add(pkRaw, 0x20), off))
            }
            dpk.rho = rhoLegacy;
        }

        // t1[0][0..3] — old FIPSPack mode:
        // first 4 coefficients are taken from pkRaw[32..36] (5 bytes)
        if (len >= 32 + 5) {
            uint256 base = 32;

            uint16 b0 = uint16(uint8(pkRaw[base]));
            uint16 b1 = uint16(uint8(pkRaw[base + 1]));
            uint16 b2 = uint16(uint8(pkRaw[base + 2]));
            uint16 b3 = uint16(uint8(pkRaw[base + 3]));
            uint16 b4 = uint16(uint8(pkRaw[base + 4]));

            uint16 t0 = uint16((b0 | (b1 << 8)) & 0x03FF);
            uint16 t1c = uint16(((b1 >> 2) | (b2 << 6)) & 0x03FF);
            uint16 t2c = uint16(((b2 >> 4) | (b3 << 4)) & 0x03FF);
            uint16 t3c = uint16(((b3 >> 6) | (b4 << 2)) & 0x03FF);

            dpk.t1.polys[0][0] = int32(int16(t0));
            dpk.t1.polys[0][1] = int32(int16(t1c));
            dpk.t1.polys[0][2] = int32(int16(t2c));
            dpk.t1.polys[0][3] = int32(int16(t3c));
        }

        // if len < 32 or < 37 — simply return with default rho=0, t1=0
    }

    /// @dev Unpacks t1 from the first 1920 bytes of src into PolyVecK.
    /// Expected format: for each of K polynomials:
    /// 256 coefficients of 10 bits, packed as 64 groups of 4 coeffs → 5 bytes.
    function _decodeT1Packed(
        bytes memory src,
        MLDSA65_PolyVec.PolyVecK memory t1
    ) internal pure {
        require(src.length >= T1_PACKED_BYTES, "t1 too short");

        uint256 byteOffset = 0;

        // K = 6 polynomials
        for (uint256 k = 0; k < MLDSA65_PolyVec.K; ++k) {
            // 64 groups of 4 coefficients per polynomial
            for (uint256 group = 0; group < 64; ++group) {
                uint256 idx = byteOffset;

                uint16 b0 = uint16(uint8(src[idx + 0]));
                uint16 b1 = uint16(uint8(src[idx + 1]));
                uint16 b2 = uint16(uint8(src[idx + 2]));
                uint16 b3 = uint16(uint8(src[idx + 3]));
                uint16 b4 = uint16(uint8(src[idx + 4]));

                byteOffset += 5;

                uint256 baseIdx = group * 4;

                uint16 t0 = (b0 | ((b1 & 0x03) << 8)) & 0x03FF;
                uint16 t1c = ((b1 >> 2) | ((b2 & 0x0F) << 6)) & 0x03FF;
                uint16 t2 = ((b2 >> 4) | ((b3 & 0x3F) << 4)) & 0x03FF;
                uint16 t3 = ((b3 >> 6) | (b4 << 2)) & 0x03FF;

                t1.polys[k][baseIdx + 0] = int32(uint32(t0));
                t1.polys[k][baseIdx + 1] = int32(uint32(t1c));
                t1.polys[k][baseIdx + 2] = int32(uint32(t2));
                t1.polys[k][baseIdx + 3] = int32(uint32(t3));
            }
        }
    }

    /// @notice Decode signature bytes into a structured view.
    /// @dev Behaviour:
    /// - if len >= 32: c = last 32 bytes; prefix before that = z (sequence of LE-coeffs)
    /// - if len < 32: c remains 0; entire buffer is used for z
    /// In all cases function MUST NOT revert on short signatures.
    function _decodeSignatureRaw(
        bytes memory sigRaw
    ) internal pure returns (DecodedSignature memory dsig) {
        uint256 len = sigRaw.length;

        // 1) c: only if there are 32 bytes at the end
        if (len >= 32) {
            uint256 cOffset = len - 32;
            bytes32 cBytes;
            assembly {
                cBytes := mload(add(add(sigRaw, 0x20), cOffset))
            }
            dsig.c = cBytes;
        }

        // 2) z: prefix before c (if len>=32) or the whole buffer (if len<32)
        uint256 coeffBytes = len >= 32 ? (len - 32) : len;
        uint256 coeffCount = coeffBytes / 4; // number of full 32-bit coeffs we have
        uint256 idx = 0;

        if (coeffCount > 0) {
            for (uint256 j = 0; j < MLDSA65_PolyVec.L && idx < coeffCount; ++j) {
                for (uint256 i = 0; i < MLDSA65_PolyVec.N && idx < coeffCount; ++i) {
                    uint256 off = idx * 4;
                    // off + 4 is always <= sigRaw.length thanks to:
                    // idx < coeffCount = floor(coeffBytes/4) and coeffBytes <= len.
                    int32 coeff = _decodeCoeffLE(sigRaw, off);
                    dsig.z.polys[j][i] = coeff;
                    unchecked {
                        ++idx;
                    }
                }
            }
        }

        // 3) h remains zero (HintVecL defaults to all zeros)
    }

    //
    // Low-level coeff decode
    //

    /// @notice Decode a single coefficient from 4 bytes in little-endian order, reduced mod Q.
    /// @dev Low-level helper; will also be used in real FIPS-204 packing.
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

        uint32 q = uint32(uint32(uint256(int256(Q))));
        uint32 reduced = v % q;

        return int32(int256(uint256(reduced)));
    }

    //
    // Synthetic ExpandA(rho) — still test-only A, NOT real FIPS-204 ExpandA
    //

    /// @notice Synthetic A[row][col] poly in the time domain via MLDSA65_ExpandA.
    function _expandA_poly(
        bytes32 rho,
        uint8 row,
        uint8 col
    ) internal pure returns (int32[256] memory a) {
        a = MLDSA65_ExpandA.expandA_poly(rho, row, col);
    }

    /// @notice Synthetic A[row][col] poly in NTT domain.
    /// @dev Uses MLDSA65_ExpandA.expandA_poly (time-domain synthetic ExpandA),
    ///      then bridges via PolyVecL.nttL into the NTT domain.
    function _expandA_poly_ntt(
        bytes32 rho,
        uint8 row,
        uint8 col
    ) internal pure returns (int32[256] memory a_ntt) {
        // 1) Generate A in the time domain via separate ExpandA library
        int32[256] memory a = _expandA_poly(rho, row, col);

        // 2) Wrap into PolyVecL to reuse the NTT bridge
        MLDSA65_PolyVec.PolyVecL memory tmp;
        tmp.polys[0] = a;

        MLDSA65_PolyVec.PolyVecL memory tmpNTT = MLDSA65_PolyVec.nttL(tmp);

        // 3) Extract the first polynomial back
        a_ntt = tmpNTT.polys[0];
    }

    //
    // Temporary norm check for z (POC-level)
    //

    /// @notice Loose bound check on z coefficients.
    /// @dev This is NOT the final FIPS-204 gamma1-based norm check.
    ///      It only ensures that z is not obviously malformed.
    ///      TODO: Replace with proper ||z||∞ < γ₁ - β check per FIPS-204.
    function _checkZNormLoose(
        DecodedSignature memory dsig
    ) internal pure returns (bool) {
        int32 maxAbs = 1000000; // TODO: replace with gamma1 bound from FIPS-204

        for (uint256 j = 0; j < MLDSA65_PolyVec.L; ++j) {
            for (uint256 i = 0; i < MLDSA65_PolyVec.N; ++i) {
                int32 v = dsig.z.polys[j][i];
                if (v > maxAbs || v < -maxAbs) {
                    return false;
                }
            }
        }

        return true;
    }

    //
    // Structural placeholder for w = A * z - c * t1
    //

    /// @notice Synthetic w = A·z - c·t1 in the NTT domain.
    /// @dev A is generated via _expandA_poly_ntt (synthetic ExpandA),
    ///      z is converted to NTT once, c is expanded to a small challenge polynomial,
    ///      t1 is converted to NTT per row.
    ///      This is still NOT a full FIPS-204 verify pipeline: decomposition and hints are
    ///      explicitly left out-of-scope for this contract version.
    function _compute_w(
        DecodedPublicKey memory dpk,
        DecodedSignature memory dsig
    ) internal pure returns (MLDSA65_PolyVec.PolyVecK memory w) {
        bytes32 rho = dpk.rho;

        // 1) NTT(z)
        MLDSA65_PolyVec.PolyVecL memory z_ntt = MLDSA65_PolyVec.nttL(dsig.z);

        // 2) Optional challenge polynomial in NTT domain (only if c != 0)
        bool hasChallenge = (dsig.c != bytes32(0));
        int32[256] memory c_ntt;
        if (hasChallenge) {
            int32[256] memory c_poly = MLDSA65_Challenge.challengePoly(dsig.c);
            c_ntt = MLDSA65_PolyVec._nttPoly(c_poly);
        }

        // 3) For each row k: w[k] = INTT( Σ_j A_ntt[k,j] ∘ z_ntt[j] - c_ntt ∘ t1_ntt[k] )
        for (uint256 k = 0; k < MLDSA65_PolyVec.K; ++k) {
            int32[256] memory acc_ntt; // zero in NTT domain

            // A·z part
            for (uint256 j = 0; j < MLDSA65_PolyVec.L; ++j) {
                int32[256] memory a_ntt = _expandA_poly_ntt(
                    rho,
                    uint8(k),
                    uint8(j)
                );

                int32[256] memory prod_ntt = MLDSA65_Poly.pointwiseMul(
                    a_ntt,
                    z_ntt.polys[j]
                );

                acc_ntt = MLDSA65_Poly.add(acc_ntt, prod_ntt);
            }

            // - c·t1 part (only if we have a non-zero challenge seed)
            if (hasChallenge) {
                int32[256] memory t1_ntt = MLDSA65_PolyVec._nttPoly(
                    dpk.t1.polys[k]
                );
                int32[256] memory ct1_ntt = MLDSA65_Poly.pointwiseMul(
                    c_ntt,
                    t1_ntt
                );
                acc_ntt = MLDSA65_Poly.sub(acc_ntt, ct1_ntt);
            }

            // Back to time domain via PolyVecK.inttK
            MLDSA65_PolyVec.PolyVecK memory tmpK;
            tmpK.polys[0] = acc_ntt;

            MLDSA65_PolyVec.PolyVecK memory tmpK_time = MLDSA65_PolyVec.inttK(
                tmpK
            );
            w.polys[k] = tmpK_time.polys[0];
        }

        // hints are still unused; full decomposition/hint logic is out-of-scope here
        dsig.h;

        return w;
    }
}
