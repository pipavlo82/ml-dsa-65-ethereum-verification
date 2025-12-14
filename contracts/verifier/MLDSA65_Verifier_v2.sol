// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NTT_MLDSA_Real} from "../ntt/NTT_MLDSA_Real.sol";
import {MLDSA65_ExpandA_KeccakFIPS204} from "./MLDSA65_ExpandA_KeccakFIPS204.sol";
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
// Polynomial core (uint256 poly)
// =============================
//

/// @notice Polynomial helpers for ML-DSA-65 using uint256 representation.
/// @dev Operations in uint256[256] for efficient modular arithmetic.
library MLDSA65_PolyU {
    uint256 internal constant N = 256;
    uint256 internal constant Q = 8380417;

    function addQ(uint256[256] memory a, uint256[256] memory b)
        internal pure returns (uint256[256] memory r)
    {
        unchecked {
            for (uint256 i = 0; i < N; ++i) {
                r[i] = addmod(a[i], b[i], Q);
            }
        }
    }

    function subQ(uint256[256] memory a, uint256[256] memory b)
        internal pure returns (uint256[256] memory r)
    {
        unchecked {
            for (uint256 i = 0; i < N; ++i) {
                r[i] = addmod(a[i], Q - (b[i] % Q), Q);
            }
        }
    }

    function pointwiseMulQ(uint256[256] memory a, uint256[256] memory b)
        internal pure returns (uint256[256] memory r)
    {
        unchecked {
            for (uint256 i = 0; i < N; ++i) {
                r[i] = mulmod(a[i], b[i], Q);
            }
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
    uint256 internal constant L = 5; // length of z (polyvecL)
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

    // ---------------------------------------------------------------------
    // LEGACY int32 NTT path (unused in current verifier). Keep for old tests.
    // Prefer uint256 path: _toUQ + _nttU/_inttU for gas and clarity.
    // ---------------------------------------------------------------------

    function _toNTTDomain(
        int32[256] memory a
    ) internal pure returns (uint256[256] memory r) {
        int256 q = int256(int32(Q));
        for (uint256 i = 0; i < N; ++i) {
            int256 v = int256(a[i]);
            if (v >= 0 && v < q) {
                r[i] = uint256(v);
            } else {
                v %= q;
                if (v < 0) v += q;
                r[i] = uint256(v);
            }
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

    function _toUQ(int32[256] memory a) internal pure returns (uint256[256] memory r) {
        int256 q = int256(int32(Q));
        unchecked {
            for (uint256 i = 0; i < N; ++i) {
                int256 v = int256(a[i]);
                if (v >= 0 && v < q) {
                    r[i] = uint256(v);
                } else {
                    v %= q;
                    if (v < 0) v += q;
                    r[i] = uint256(v);
                }
            }
        }
    }

    function _toUQ_into(int32[256] memory a, uint256[256] memory out) internal pure {
        int256 q = int256(int32(Q));
        unchecked {
            for (uint256 i = 0; i < N; ++i) {
                int256 v = int256(a[i]);
                if (v >= 0 && v < q) {
                    out[i] = uint256(v);
                } else {
                    v %= q;
                    if (v < 0) v += q;
                    out[i] = uint256(v);
                }
            }
        }
    }

    function _nttU_into(uint256[256] memory a, uint256[256] memory out) internal pure {
        uint256[256] memory r = NTT_MLDSA_Real.ntt(a);
        unchecked {
            for (uint256 i = 0; i < N; ++i) out[i] = r[i];
        }
    }

    function _inttU_into(uint256[256] memory a, uint256[256] memory out) internal pure {
        uint256[256] memory r = NTT_MLDSA_Real.intt(a);
        unchecked {
            for (uint256 i = 0; i < N; ++i) out[i] = r[i];
        }
    }

    function _nttU(uint256[256] memory a) internal pure returns (uint256[256] memory r) {
        r = NTT_MLDSA_Real.ntt(a);
    }

    function _inttU(uint256[256] memory a) internal pure returns (uint256[256] memory r) {
        r = NTT_MLDSA_Real.intt(a);
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
    uint256 internal constant K = 6; // hint for t1/w (polyvecK)
    uint256 internal constant L = 5; // legacy/aux hint dimension (not used in FIPS verify)

    /// @notice Hint vector: flags in {-1, 0, 1} per coefficient.
    struct HintVecL {
        int8[256][L] flags;
    }

    /// @notice Hint vector for K-dimension: flags in {-1, 0, 1} per coefficient.
    struct HintVecK {
        int8[256][K] flags;
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

    /// @notice Basic sanity check for K-dimension hints: all flags must be in {-1, 0, 1}.
    function isValidHintK(HintVecK memory h) internal pure returns (bool) {
        for (uint256 j = 0; j < K; ++j) {
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

    /// @notice Placeholder applyHint for PolyVecK.
    /// @dev Currently identity; real logic will be added together with full decomposition.
    function applyHintK(
        MLDSA65_PolyVec.PolyVecK memory w,
        HintVecK memory /*h*/
    ) internal pure returns (MLDSA65_PolyVec.PolyVecK memory out) {
        return w;
    }
}

//
// ===================
// Verifier skeleton
// ===================
//

/// @notice ML-DSA-65 Verifier v2 – skeleton for the real verification pipeline.
/// @dev Currently contains: ABI, decode layer, Keccak/FIPS ExpandA, and w = A·z - c·t1.
///      Full FIPS-204 decomposition/hints are explicitly out-of-scope for this version.
contract MLDSA65_Verifier_v2 {
    using MLDSA65_Poly for int32[256];

    int32 internal constant Q = 8380417;
    // For ML-DSA-65 (Dilithium3-level) γ₁ = 2¹⁹.
    int32 internal constant GAMMA1 = int32(1 << 19);
    // Temporary z-norm bound used in verify(): |z_i| < γ₁.
    // TODO: if needed, tighten to (γ₁ - β) once β is wired in.
    int32 internal constant Z_NORM_BOUND = GAMMA1 - 1;

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
        MLDSA65_Hint.HintVecK h;
    }

    /// @notice Main verification entrypoint with basic structural checks.
    /// @dev This is NOT yet a full FIPS-204 verifier. Currently performs:
    ///      - Structural validation (lengths, c != 0, loose z norm)
    ///      - Computes w = A·z - c·t1 (Keccak/FIPS ExpandA + NTT-domain)
    ///      - Checks that challenge polynomial derived from signature seed equals
    ///        the polynomial derived from message_digest (POC consistency)
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

        // 2) z must have coefficients within γ₁ bound.
        if (!_checkZNormGamma1Bound(dsig)) {
            return false;
        }

        // 3) Compute w = A*z - c*t1 (in NTT domain; decomposition/hints out of scope).
        MLDSA65_PolyVec.PolyVecK memory w = _compute_w(dpk, dsig);
        w; // unused until full decomposition/hints are wired

        // 4) FIPS-style challenge consistency (POC):
        int32[256] memory c_from_sig = MLDSA65_Challenge.poly_challenge(dsig.c);
        int32[256] memory c_from_msg = MLDSA65_Challenge.poly_challenge(message_digest);

        if (!_polyEq(c_from_sig, c_from_msg)) {
            return false;
        }

        return true;
    }

    //
    // Decode helpers – overloads for test compatibility
    //

    function _decodePublicKey(
        PublicKey memory pk
    ) internal pure returns (DecodedPublicKey memory dpk) {
        return _decodePublicKeyRaw(pk.raw);
    }

    function _decodePublicKey(
        bytes memory pkRaw
    ) internal pure returns (DecodedPublicKey memory dpk) {
        return _decodePublicKeyRaw(pkRaw);
    }

    function _decodeSignature(
        Signature memory sig
    ) internal pure returns (DecodedSignature memory dsig) {
        return _decodeSignatureRaw(sig.raw);
    }

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
    /// - len >= PK_MIN_LEN (1952): full FIPS unpack t1 + rho
    /// - len < PK_MIN_LEN: legacy mode (rho from last 32; first 4 coeffs from offset 32)
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

        // 2) Legacy mode.

        // rho = last 32 bytes, if available
        if (len >= 32) {
            uint256 off = len - 32;
            bytes32 rhoLegacy;
            assembly {
                rhoLegacy := mload(add(add(pkRaw, 0x20), off))
            }
            dpk.rho = rhoLegacy;
        }

        // t1[0][0..3] — old harness behavior:
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

        for (uint256 k = 0; k < MLDSA65_PolyVec.K; ++k) {
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
    /// @dev MUST NOT revert on short signatures.
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
                    int32 coeff = _decodeCoeffLE(sigRaw, off);
                    dsig.z.polys[j][i] = coeff;
                    unchecked {
                        ++idx;
                    }
                }
            }
        }

        // 3) h remains zero (defaults)
    }

    /// @notice Decode a single coefficient from 4 bytes in little-endian order, reduced mod Q.
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
    // Keccak-based FIPS-204 ExpandA(rho)
    //

    function _expandA_poly(
        bytes32 rho,
        uint8 row,
        uint8 col
    ) internal pure returns (int32[256] memory a) {
        if (row >= MLDSA65_PolyVec.K || col >= MLDSA65_PolyVec.L) {
            revert("ExpandA: idx");
        }
        a = MLDSA65_ExpandA_KeccakFIPS204.expandA_poly(rho, row, col);
    }

    function _expandA_poly_ntt(
        bytes32 rho,
        uint8 row,
        uint8 col
    ) internal pure returns (int32[256] memory a_ntt) {
        int32[256] memory a = _expandA_poly(rho, row, col);
        a_ntt = MLDSA65_PolyVec._nttPoly(a);
    }

    function _expandA_poly_ntt_u(
        bytes32 rho,
        uint8 row,
        uint8 col
    ) internal pure returns (uint256[256] memory a_ntt_u) {
        int32[256] memory a = _expandA_poly(rho, row, col);
        uint256[256] memory au = MLDSA65_PolyVec._toUQ(a);
        a_ntt_u = MLDSA65_PolyVec._nttU(au);
    }

    function _expandA_poly_ntt_u_into(
        bytes32 rho,
        uint8 row,
        uint8 col,
        uint256[256] memory out_ntt_u
    ) internal pure {
        int32[256] memory a = _expandA_poly(rho, row, col);
        uint256[256] memory tmp_u = MLDSA65_PolyVec._toUQ(a);
        MLDSA65_PolyVec._nttU_into(tmp_u, out_ntt_u);
    }

    function _expandA_matrix_keccak(
        bytes32 rho
    )
        internal
        pure
        returns (int32[6][5][256] memory A)
    {
        unchecked {
            for (uint8 row = 0; row < MLDSA65_PolyVec.K; ++row) {
                for (uint8 col = 0; col < MLDSA65_PolyVec.L; ++col) {
                    int32[256] memory poly =
                        MLDSA65_ExpandA_KeccakFIPS204.expandA_poly(rho, row, col);

                    for (uint256 i = 0; i < MLDSA65_PolyVec.N; ++i) {
                        A[row][col][i] = poly[i];
                    }
                }
            }
        }
    }

    //
    // Temporary norm check for z (POC-level)
    //

    function _checkZNormGamma1Bound(
        DecodedSignature memory dsig
    ) internal pure returns (bool) {
        int32 maxAbs = Z_NORM_BOUND;

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

    function _polyEq(
        int32[256] memory a,
        int32[256] memory b
    ) internal pure returns (bool) {
        for (uint256 i = 0; i < 256; ++i) {
            if (a[i] != b[i]) {
                return false;
            }
        }
        return true;
    }

    //
    // w = A * z - c * t1 (Keccak-based ExpandA)
    //

    function _compute_w(
        DecodedPublicKey memory dpk,
        DecodedSignature memory dsig
    ) internal pure returns (MLDSA65_PolyVec.PolyVecK memory w) {
        bytes32 rho = dpk.rho;

        // 1) z_ntt_u[j]
        uint256[256][5] memory z_ntt_u;
        for (uint256 j = 0; j < MLDSA65_PolyVec.L; ++j) {
            uint256[256] memory zu = MLDSA65_PolyVec._toUQ(dsig.z.polys[j]);
            z_ntt_u[j] = MLDSA65_PolyVec._nttU(zu);
        }

        // 2) c_ntt_u (optional)
        bool hasChallenge = (dsig.c != bytes32(0));
        uint256[256] memory c_ntt_u;
        if (hasChallenge) {
            int32[256] memory c_poly = MLDSA65_Challenge.poly_challenge(dsig.c);
            uint256[256] memory cu = MLDSA65_PolyVec._toUQ(c_poly);
            c_ntt_u = MLDSA65_PolyVec._nttU(cu);
        }

        // 2.5) t1_ntt_u[k] - pre-compute once
        uint256[256][6] memory t1_ntt_u;
        for (uint256 k = 0; k < MLDSA65_PolyVec.K; ++k) {
            uint256[256] memory t1u = MLDSA65_PolyVec._toUQ(dpk.t1.polys[k]);
            t1_ntt_u[k] = MLDSA65_PolyVec._nttU(t1u);
        }

        // 3) for each row k
        for (uint256 k = 0; k < MLDSA65_PolyVec.K; ++k) {
            uint256[256] memory acc_ntt_u;

            // Phase 8.x:
            // A·z, and fuse -c·t1 only once in the last column (j == L-1)
            for (uint256 j = 0; j < MLDSA65_PolyVec.L; ++j) {
                uint256[256] memory a_ntt_u = _expandA_poly_ntt_u(rho, uint8(k), uint8(j));

                if (hasChallenge && j == (MLDSA65_PolyVec.L - 1)) {
                    assembly {
                        let q := 8380417

                        let accPtr := acc_ntt_u
                        let aPtr   := a_ntt_u
                        let zPtr   := mload(add(z_ntt_u, mul(j, 0x20)))
                        let cPtr   := c_ntt_u
                        let t1Ptr  := mload(add(t1_ntt_u, mul(k, 0x20)))

                        for { let off := 0 } lt(off, 0x2000) { off := add(off, 0x40) } {
                            // lane0
                            {
                                let accv := mload(add(accPtr, off))

                                let prod := mulmod(mload(add(aPtr, off)), mload(add(zPtr, off)), q)
                                accv := addmod(accv, prod, q)

                                let term := mulmod(mload(add(cPtr, off)), mload(add(t1Ptr, off)), q)
                                accv := addmod(accv, sub(q, term), q)

                                mstore(add(accPtr, off), accv)
                            }
                            // lane1
                            {
                                let off1 := add(off, 0x20)
                                let accv := mload(add(accPtr, off1))

                                let prod := mulmod(mload(add(aPtr, off1)), mload(add(zPtr, off1)), q)
                                accv := addmod(accv, prod, q)

                                let term := mulmod(mload(add(cPtr, off1)), mload(add(t1Ptr, off1)), q)
                                accv := addmod(accv, sub(q, term), q)

                                mstore(add(accPtr, off1), accv)
                            }
                        }
                    }
                } else {
                    assembly {
                        let q := 8380417

                        let accPtr := acc_ntt_u
                        let aPtr   := a_ntt_u
                        let zPtr   := mload(add(z_ntt_u, mul(j, 0x20)))

                        for { let off := 0 } lt(off, 0x2000) { off := add(off, 0x40) } {
                            // lane0
                            {
                                let accv := mload(add(accPtr, off))
                                let prod := mulmod(mload(add(aPtr, off)), mload(add(zPtr, off)), q)
                                accv := addmod(accv, prod, q)
                                mstore(add(accPtr, off), accv)
                            }
                            // lane1
                            {
                                let off1 := add(off, 0x20)
                                let accv := mload(add(accPtr, off1))
                                let prod := mulmod(mload(add(aPtr, off1)), mload(add(zPtr, off1)), q)
                                accv := addmod(accv, prod, q)
                                mstore(add(accPtr, off1), accv)
                            }
                        }
                    }
                }
            }

            // Back to time domain
            uint256[256] memory w_u = MLDSA65_PolyVec._inttU(acc_ntt_u);

            // Phase 8.2: inttU already yields residues in [0, Q),
            // so `% Q` is redundant. Q < 2^32, cast is safe.
            for (uint256 i = 0; i < MLDSA65_PolyVec.N; ++i) {
                w.polys[k][i] = int32(uint32(w_u[i]));
            }
        }

        dsig.h;
        return w;
    }
}
