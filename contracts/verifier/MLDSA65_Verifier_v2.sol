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

    /// @notice r = a ∘ b (pointwise) mod q
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

    function addL(
        PolyVecL memory a,
        PolyVecL memory b
    ) internal pure returns (PolyVecL memory r) {
        for (uint256 i = 0; i < L; ++i) {
            r.polys[i] = MLDSA65_Poly.add(a.polys[i], b.polys[i]);
        }
    }

    function subL(
        PolyVecL memory a,
        PolyVecL memory b
    ) internal pure returns (PolyVecL memory r) {
        for (uint256 i = 0; i < L; ++i) {
            r.polys[i] = MLDSA65_Poly.sub(a.polys[i], b.polys[i]);
        }
    }

    function addK(
        PolyVecK memory a,
        PolyVecK memory b
    ) internal pure returns (PolyVecK memory r) {
        for (uint256 i = 0; i < K; ++i) {
            r.polys[i] = MLDSA65_Poly.add(a.polys[i], b.polys[i]);
        }
    }

    function subK(
        PolyVecK memory a,
        PolyVecK memory b
    ) internal pure returns (PolyVecK memory r) {
        for (uint256 i = 0; i < K; ++i) {
            r.polys[i] = MLDSA65_Poly.sub(a.polys[i], b.polys[i]);
        }
    }

    // ---------------------------------------------------------------------
    // LEGACY int32 NTT path (kept for tests / clarity).
    // Prefer uint256 path: _toUQ + _nttU/_inttU for gas and correctness.
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

    // -----------------------------
    // uint256 NTT path (fast path)
    // -----------------------------

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
                if (v >= 0 && v < q) out[i] = uint256(v);
                else {
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

    // -----------------------------
    // legacy bridge helpers (tests)
    // -----------------------------

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

    function nttL(PolyVecL memory v) internal pure returns (PolyVecL memory r) {
        for (uint256 j = 0; j < L; ++j) r.polys[j] = _nttPoly(v.polys[j]);
    }

    function inttL(PolyVecL memory v) internal pure returns (PolyVecL memory r) {
        for (uint256 j = 0; j < L; ++j) r.polys[j] = _inttPoly(v.polys[j]);
    }

    function nttK(PolyVecK memory v) internal pure returns (PolyVecK memory r) {
        for (uint256 k = 0; k < K; ++k) r.polys[k] = _nttPoly(v.polys[k]);
    }

    function inttK(PolyVecK memory v) internal pure returns (PolyVecK memory r) {
        for (uint256 k = 0; k < K; ++k) r.polys[k] = _inttPoly(v.polys[k]);
    }
}

//
// ============
// Hint layer
// ============
//

library MLDSA65_Hint {
    uint256 internal constant N = 256;
    uint256 internal constant K = 6;
    uint256 internal constant L = 5;

    struct HintVecL {
        int8[256][L] flags;
    }

    struct HintVecK {
        int8[256][K] flags;
    }

    function isValidHint(HintVecL memory h) internal pure returns (bool) {
        for (uint256 j = 0; j < L; ++j) {
            for (uint256 i = 0; i < N; ++i) {
                int8 v = h.flags[j][i];
                if (v < -1 || v > 1) return false;
            }
        }
        return true;
    }

    function isValidHintK(HintVecK memory h) internal pure returns (bool) {
        for (uint256 j = 0; j < K; ++j) {
            for (uint256 i = 0; i < N; ++i) {
                int8 v = h.flags[j][i];
                if (v < -1 || v > 1) return false;
            }
        }
        return true;
    }

    function applyHintL(
        MLDSA65_PolyVec.PolyVecL memory w,
        HintVecL memory /*h*/
    ) internal pure returns (MLDSA65_PolyVec.PolyVecL memory out) {
        return w;
    }

    function applyHintK(
        MLDSA65_PolyVec.PolyVecK memory w,
        HintVecK memory /*h*/
    ) internal pure returns (MLDSA65_PolyVec.PolyVecK memory out) {
        return w;
    }
}

//
// ===================
// Verifier v2 (POC)
// ===================
//

/// @notice ML-DSA-65 Verifier v2 – decode + ExpandA(Keccak/FIPS) + w = A·z − c·t1.
/// @dev Not a full FIPS-204 verifier yet (decomp/hints out of scope).
contract MLDSA65_Verifier_v2 {
    using MLDSA65_Poly for int32[256];

    int32 internal constant Q = 8380417;
    int32 internal constant GAMMA1 = int32(1 << 19);
    int32 internal constant Z_NORM_BOUND = GAMMA1 - 1;

    // t1: 6 polys × 256 coeff × 10-bit packed => 1920 bytes
    uint256 internal constant T1_PACKED_BYTES = 1920;
    uint256 internal constant RHO_BYTES = 32;
    uint256 internal constant PK_MIN_LEN = T1_PACKED_BYTES + RHO_BYTES; // 1952

    struct PublicKey {
        bytes raw; // 1952 bytes in FIPS mode
    }

    struct Signature {
        bytes raw; // 3309 bytes in FIPS mode (but decode is tolerant)
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

    function verify(
        PublicKey memory pk,
        Signature memory sig,
        bytes32 message_digest
    ) external pure returns (bool) {
        if (pk.raw.length < 32 || sig.raw.length < 32) return false;

        DecodedPublicKey memory dpk = _decodePublicKey(pk);
        DecodedSignature memory dsig = _decodeSignature(sig);

        if (dsig.c == bytes32(0)) return false;
        if (!_checkZNormGamma1Bound(dsig)) return false;

        MLDSA65_PolyVec.PolyVecK memory w = _compute_w(dpk, dsig);
        w; // not used until full decomposition/hints are wired

        int32[256] memory c_from_sig = MLDSA65_Challenge.poly_challenge(dsig.c);
        int32[256] memory c_from_msg = MLDSA65_Challenge.poly_challenge(message_digest);
        if (!_polyEq(c_from_sig, c_from_msg)) return false;

        return true;
    }

    // ---- decode overloads

    function _decodePublicKey(PublicKey memory pk) internal pure returns (DecodedPublicKey memory dpk) {
        return _decodePublicKeyRaw(pk.raw);
    }

    function _decodePublicKey(bytes memory pkRaw) internal pure returns (DecodedPublicKey memory dpk) {
        return _decodePublicKeyRaw(pkRaw);
    }

    function _decodeSignature(Signature memory sig) internal pure returns (DecodedSignature memory dsig) {
        return _decodeSignatureRaw(sig.raw);
    }

    function _decodeSignature(bytes memory sigRaw) internal pure returns (DecodedSignature memory dsig) {
        return _decodeSignatureRaw(sigRaw);
    }

    // ---- decode (raw)

    function _decodePublicKeyRaw(bytes memory pkRaw) internal pure returns (DecodedPublicKey memory dpk) {
        uint256 len = pkRaw.length;

        if (len >= PK_MIN_LEN) {
            // rho = last 32 bytes
            uint256 rhoOffset = len - RHO_BYTES;
            bytes32 rhoBytes;
            assembly {
                rhoBytes := mload(add(add(pkRaw, 0x20), rhoOffset))
            }
            dpk.rho = rhoBytes;

            // t1 = first 1920 bytes (packed 10-bit)
            _decodeT1Packed(pkRaw, dpk.t1);
            return dpk;
        }

        // legacy fallback
        if (len >= 32) {
            uint256 off = len - 32;
            bytes32 rhoLegacy;
            assembly {
                rhoLegacy := mload(add(add(pkRaw, 0x20), off))
            }
            dpk.rho = rhoLegacy;
        }

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

    function _decodeT1Packed(bytes memory src, MLDSA65_PolyVec.PolyVecK memory t1) internal pure {
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

    function _decodeSignatureRaw(bytes memory sigRaw) internal pure returns (DecodedSignature memory dsig) {
        uint256 len = sigRaw.length;

        // c = last 32 bytes if present
        if (len >= 32) {
            uint256 cOffset = len - 32;
            bytes32 cBytes;
            assembly {
                cBytes := mload(add(add(sigRaw, 0x20), cOffset))
            }
            dsig.c = cBytes;
        }

        // z = prefix before c (or whole buffer if len<32)
        uint256 coeffBytes = len >= 32 ? (len - 32) : len;
        uint256 coeffCount = coeffBytes / 4;
        uint256 idx = 0;

        if (coeffCount > 0) {
            for (uint256 j = 0; j < MLDSA65_PolyVec.L && idx < coeffCount; ++j) {
                for (uint256 i = 0; i < MLDSA65_PolyVec.N && idx < coeffCount; ++i) {
                    uint256 off = idx * 4;
                    int32 coeff = _decodeCoeffLE(sigRaw, off);
                    dsig.z.polys[j][i] = coeff;
                    unchecked { ++idx; }
                }
            }
        }
        // h defaults to zero
    }

    function _decodeCoeffLE(bytes memory src, uint256 offset) internal pure returns (int32) {
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

    // ---- ExpandA (Keccak/FIPS-204)

    function _expandA_poly(bytes32 rho, uint8 row, uint8 col) internal pure returns (int32[256] memory a) {
        if (row >= MLDSA65_PolyVec.K || col >= MLDSA65_PolyVec.L) revert("ExpandA: idx");
        a = MLDSA65_ExpandA_KeccakFIPS204.expandA_poly(rho, row, col);
    }

    function _expandA_poly_ntt_u_into_ws(
        bytes32 rho,
        uint8 row,
        uint8 col,
        uint256[256] memory tmp_u_ws,
        uint256[256] memory out_ntt_u
    ) internal pure {
        int32[256] memory a = _expandA_poly(rho, row, col);
        MLDSA65_PolyVec._toUQ_into(a, tmp_u_ws);
        MLDSA65_PolyVec._nttU_into(tmp_u_ws, out_ntt_u);
    }

    // ---- z norm check (POC)

    function _checkZNormGamma1Bound(DecodedSignature memory dsig) internal pure returns (bool) {
        int32 maxAbs = Z_NORM_BOUND;

        for (uint256 j = 0; j < MLDSA65_PolyVec.L; ++j) {
            for (uint256 i = 0; i < MLDSA65_PolyVec.N; ++i) {
                int32 v = dsig.z.polys[j][i];
                if (v > maxAbs || v < -maxAbs) return false;
            }
        }
        return true;
    }

    function _polyEq(int32[256] memory a, int32[256] memory b) internal pure returns (bool) {
        for (uint256 i = 0; i < 256; ++i) if (a[i] != b[i]) return false;
        return true;
    }

    // ---- w = A*z - c*t1 (Phase 9-A+B optimized)

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

        // 2.5) t1_ntt_u[k] - precompute once
        uint256[256][6] memory t1_ntt_u;
        for (uint256 k = 0; k < MLDSA65_PolyVec.K; ++k) {
            uint256[256] memory t1u = MLDSA65_PolyVec._toUQ(dpk.t1.polys[k]);
            t1_ntt_u[k] = MLDSA65_PolyVec._nttU(t1u);
        }

        // 3) for each row k
        for (uint256 k = 0; k < MLDSA65_PolyVec.K; ++k) {
            uint256[256] memory acc_ntt_u;

            // workspace buffers (allocated once per k)
            uint256[256] memory a_ntt_u;
            uint256[256] memory tmp_u_ws;

            if (!hasChallenge) {
                // Pure A·z
                for (uint256 j = 0; j < MLDSA65_PolyVec.L; ++j) {
                    _expandA_poly_ntt_u_into_ws(rho, uint8(k), uint8(j), tmp_u_ws, a_ntt_u);

                    assembly {
                        let q := 8380417
                        let accPtr := acc_ntt_u
                        let aPtr   := a_ntt_u
                        let zPtr   := mload(add(z_ntt_u, shl(5, j)))

                        // Phase 9-A: unroll ×4 (64 iterations, 4 coeffs each)
                        for { let off := 0 } lt(off, 0x2000) { off := add(off, 0x80) } {
                            // lane0 @ off
                            {
                                let accv := mload(add(accPtr, off))
                                let prod := mulmod(mload(add(aPtr, off)), mload(add(zPtr, off)), q)
                                accv := addmod(accv, prod, q)
                                mstore(add(accPtr, off), accv)
                            }
                            // lane1 @ off + 0x20
                            {
                                let off1 := add(off, 0x20)
                                let accv := mload(add(accPtr, off1))
                                let prod := mulmod(mload(add(aPtr, off1)), mload(add(zPtr, off1)), q)
                                accv := addmod(accv, prod, q)
                                mstore(add(accPtr, off1), accv)
                            }
                            // lane2 @ off + 0x40
                            {
                                let off2 := add(off, 0x40)
                                let accv := mload(add(accPtr, off2))
                                let prod := mulmod(mload(add(aPtr, off2)), mload(add(zPtr, off2)), q)
                                accv := addmod(accv, prod, q)
                                mstore(add(accPtr, off2), accv)
                            }
                            // lane3 @ off + 0x60
                            {
                                let off3 := add(off, 0x60)
                                let accv := mload(add(accPtr, off3))
                                let prod := mulmod(mload(add(aPtr, off3)), mload(add(zPtr, off3)), q)
                                accv := addmod(accv, prod, q)
                                mstore(add(accPtr, off3), accv)
                            }
                        }
                    }
                }
            } else {
                // A·z for j=0..L-2
                for (uint256 j = 0; j < (MLDSA65_PolyVec.L - 1); ++j) {
                    _expandA_poly_ntt_u_into_ws(rho, uint8(k), uint8(j), tmp_u_ws, a_ntt_u);

                    assembly {
                        let q := 8380417
                        let accPtr := acc_ntt_u
                        let aPtr   := a_ntt_u
                        let zPtr   := mload(add(z_ntt_u, shl(5, j)))

                        // Phase 9-A: unroll ×4 (64 iterations, 4 coeffs each)
                        for { let off := 0 } lt(off, 0x2000) { off := add(off, 0x80) } {
                            // lane0 @ off
                            {
                                let accv := mload(add(accPtr, off))
                                let prod := mulmod(mload(add(aPtr, off)), mload(add(zPtr, off)), q)
                                accv := addmod(accv, prod, q)
                                mstore(add(accPtr, off), accv)
                            }
                            // lane1 @ off + 0x20
                            {
                                let off1 := add(off, 0x20)
                                let accv := mload(add(accPtr, off1))
                                let prod := mulmod(mload(add(aPtr, off1)), mload(add(zPtr, off1)), q)
                                accv := addmod(accv, prod, q)
                                mstore(add(accPtr, off1), accv)
                            }
                            // lane2 @ off + 0x40
                            {
                                let off2 := add(off, 0x40)
                                let accv := mload(add(accPtr, off2))
                                let prod := mulmod(mload(add(aPtr, off2)), mload(add(zPtr, off2)), q)
                                accv := addmod(accv, prod, q)
                                mstore(add(accPtr, off2), accv)
                            }
                            // lane3 @ off + 0x60
                            {
                                let off3 := add(off, 0x60)
                                let accv := mload(add(accPtr, off3))
                                let prod := mulmod(mload(add(aPtr, off3)), mload(add(zPtr, off3)), q)
                                accv := addmod(accv, prod, q)
                                mstore(add(accPtr, off3), accv)
                            }
                        }
                    }
                }

                // last column j=L-1: fuse -c·t1
                {
                    uint256 jLast = MLDSA65_PolyVec.L - 1;
                    _expandA_poly_ntt_u_into_ws(rho, uint8(k), uint8(jLast), tmp_u_ws, a_ntt_u);

                    assembly {
                        let q := 8380417

                        let accPtr := acc_ntt_u
                        let aPtr   := a_ntt_u
                        let zPtr   := mload(add(z_ntt_u, shl(5, jLast)))
                        let cPtr   := c_ntt_u
                        let t1Ptr  := mload(add(t1_ntt_u, shl(5, k)))

                        // Phase 9-A: unroll ×4 with fused -c·t1
                        for { let off := 0 } lt(off, 0x2000) { off := add(off, 0x80) } {
                            // lane0 @ off
                            {
                                let accv := mload(add(accPtr, off))

                                let prod := mulmod(mload(add(aPtr, off)), mload(add(zPtr, off)), q)
                                accv := addmod(accv, prod, q)

                                let term := mulmod(mload(add(cPtr, off)), mload(add(t1Ptr, off)), q)
                                accv := addmod(accv, sub(q, term), q)

                                mstore(add(accPtr, off), accv)
                            }
                            // lane1 @ off + 0x20
                            {
                                let off1 := add(off, 0x20)
                                let accv := mload(add(accPtr, off1))

                                let prod := mulmod(mload(add(aPtr, off1)), mload(add(zPtr, off1)), q)
                                accv := addmod(accv, prod, q)

                                let term := mulmod(mload(add(cPtr, off1)), mload(add(t1Ptr, off1)), q)
                                accv := addmod(accv, sub(q, term), q)

                                mstore(add(accPtr, off1), accv)
                            }
                            // lane2 @ off + 0x40
                            {
                                let off2 := add(off, 0x40)
                                let accv := mload(add(accPtr, off2))

                                let prod := mulmod(mload(add(aPtr, off2)), mload(add(zPtr, off2)), q)
                                accv := addmod(accv, prod, q)

                                let term := mulmod(mload(add(cPtr, off2)), mload(add(t1Ptr, off2)), q)
                                accv := addmod(accv, sub(q, term), q)

                                mstore(add(accPtr, off2), accv)
                            }
                            // lane3 @ off + 0x60
                            {
                                let off3 := add(off, 0x60)
                                let accv := mload(add(accPtr, off3))

                                let prod := mulmod(mload(add(aPtr, off3)), mload(add(zPtr, off3)), q)
                                accv := addmod(accv, prod, q)

                                let term := mulmod(mload(add(cPtr, off3)), mload(add(t1Ptr, off3)), q)
                                accv := addmod(accv, sub(q, term), q)

                                mstore(add(accPtr, off3), accv)
                            }
                        }
                    }
                }
            }

            // Back to time domain
            uint256[256] memory w_u = MLDSA65_PolyVec._inttU(acc_ntt_u);

            // inttU yields residues in [0, Q), so `% Q` is redundant.
            for (uint256 i = 0; i < MLDSA65_PolyVec.N; ++i) {
                w.polys[k][i] = int32(uint32(w_u[i]));
            }
        }

        dsig.h; // placeholder
        return w;
    }
}
