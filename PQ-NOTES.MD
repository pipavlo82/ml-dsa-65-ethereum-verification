# PQ-NOTES — ML-DSA-65 Ethereum Verification

Working notes for the **ML-DSA-65 (FIPS-204)** verifier on Ethereum.  
Goal: a production-grade, gas-aware verification contract suitable for rollups / L2s and hybrid ECDSA + ML-DSA pipelines.

This file tracks:
- what is already implemented,
- current gas numbers,
- missing pieces before a full FIPS-204-compatible verifier.

---

## 1. Target scheme & parameters

We target the ML-DSA-65 parameter set (Dilithium3-level security):

- Ring dimension: `N = 256`
- Modulus: `q = 8380417`
- Vectors:
  - `k = 6` → `PolyVecK` for public key `t1`
  - `l = 5` → `PolyVecL` for vector `z` (and hints)
- Encodings (FIPS-204 layout):
  - `t1`: `6 × 256` coefficients, 10 bits each → **1920 bytes**
  - `rho`: **32 bytes**
  - Public key: `t1_packed || rho` → **1952 bytes**
  - Signature: target **3309 bytes** (full ML-DSA-65 signature; current code uses a simplified layout for the POC path).

---

## 2. Contract architecture (high level)

All verifier logic lives under `contracts/verifier`:

- `MLDSA65_Poly`
  - Arithmetic on a single polynomial `int32[256]` over `Z_q`:
    - `add`, `sub` (coefficient-wise, mod `q`)
    - `pointwiseMul` (reference multiply, no Montgomery yet).

- `MLDSA65_PolyVec`
  - Vector types:
    - `PolyVecL` (`l = 5`)
    - `PolyVecK` (`k = 6`)
  - Vector operations:
    - `addL / subL`, `addK / subK`
  - Bridges between time and NTT domain:
    - `_toNTTDomain(int32[256]) → uint256[256]`
    - `_fromNTTDomain(uint256[256]) → int32[256]`
    - `_nttPoly`, `_inttPoly`
    - `nttL / inttL`, `nttK / inttK`.

- `NTT_MLDSA_Real`
  - Production-style **NTT/INTT** for ML-DSA-65 using precomputed zetas.
  - Serves as the backend for `MLDSA65_PolyVec._nttPoly / _inttPoly`.

- `MLDSA65_Hint`
  - Hint vector type: `HintVecL` (int8[256][L], values in `{-1, 0, +1}`).
  - `isValidHint` sanity-checks the range.
  - `applyHintL` is currently an **identity** function (hint logic is intentionally out-of-scope for this POC).

- `MLDSA65_Challenge`
  - FIPS-style challenge polynomial helper with **exactly 60 non-zero coefficients**:
    - `poly_challenge(bytes32 seed) → int32[256]`
      - outputs a polynomial with:
        - exactly 60 non-zero entries,
        - each non-zero coefficient in `{+1, -1}`.
    - `deriveChallenge(bytes32 seed) → int8[256]`
      - legacy test-oriented API built on top of `poly_challenge` and returning `int8`.

- `MLDSA65_ExpandA`
  - Synthetic `ExpandA`:
    - `expandA_poly(rho, row, col) → int32[256]`  
      (Keccak-based, test-friendly; not a strict FIPS-204 ExpandA implementation.)

- `MLDSA65_Verifier_v2`
  - Main on-chain verifier skeleton:
    - `verify(PublicKey pk, Signature sig, bytes32 message_digest) → bool`
    - Internal helpers:
      - Decode layer for public key and signature
      - FIPS-style challenge consistency check
      - Synthetic `w = A·z − c·t1` in the NTT domain
      - Temporary bound check for `z`.

---

## 3. Decode & packing layer status

### Public key (`_decodePublicKeyRaw`)

Two modes:

1. **FIPS mode (preferred)**  
   Triggered when `pk.raw.length >= PK_MIN_LEN (1952)`:
   - Last 32 bytes → `rho`
   - First 1920 bytes → FIPS-style packed `t1`
     - Decoded by `_decodeT1Packed(bytes src, PolyVecK memory t1)`
     - Each polynomial uses 64 groups of 4 coeffs → 5 bytes (10-bit packing).

2. **Legacy mode (test harness support)**
   - For shorter buffers:
     - `rho` is still read from the last 32 bytes (if available).
     - First 5 bytes after offset 32 are decoded into the first 4 coefficients of `t1[0]`.
   - Used by older structural decode tests.

### Signature (`_decodeSignatureRaw`)

- Interprets the last 32 bytes as `c` if `len >= 32`.
- The remaining prefix is treated as a sequence of 32-bit little-endian coefficients that fill `z` in row-major order:
  - `z` is a `PolyVecL` (5 polynomials, each with 256 coefficients).
  - Any incomplete trailing bytes are ignored.
- Hints `h` are currently left as all zeros (placeholders).

The low-level helper `_decodeCoeffLE` decodes a single `int32` coefficient from 4 LE bytes and reduces it modulo `q`.

---

## 4. Challenge polynomial design

`MLDSA65_Challenge` implements a Keccak-based FIPS-style challenge:

- Input: `bytes32 seed` (can be message digest or the 32-byte seed stored in the signature).
- Output: `int32[256]` with:
  - exactly **60 non-zero coefficients**,
  - each in `{+1, -1}`,
  - all other positions are `0`.

Construction:

- Use `keccak256(seed || nonce)` to generate pseudorandom 32-byte blocks.
- Consume bytes in pairs: `(posByte, signByte)`:
  - `pos = uint256(posByte)` in `[0, 255]`
  - if `c[pos]` is already non-zero, skip
  - sign is derived from the MSB of `signByte`:
    - `msb == 0` → `+1`
    - `msb == 1` → `-1`
- Continue until 60 positions are filled.

Tests:

- `MLDSA_FIPSChallenge.t.sol`:
  - determinism w.r.t. seed,
  - exactly 60 non-zero coefficients,
  - all non-zero coefficients in `{+1, -1}`,
  - different seeds → typically different challenges.

- `MLDSA_Challenge.t.sol`:
  - `deriveChallenge()` is consistent with `poly_challenge()`.

---

## 5. NTT & matrix-vector layer

### NTT

`NTT_MLDSA_Real` + `MLDSA65_PolyVec` provide:

- Correct forward and inverse NTT:
  - Tests:
    - basis vectors roundtrip,
    - random vectors roundtrip,
    - structural sanity checks (e.g. simple distribution properties).
- Gas (approximate, from `NTT_MLDSA_Real_Test`):
  - single roundtrip on random vector: ~2.7M gas
  - basis-vector stress test is more expensive but serves mainly as a correctness guard.

### Matrix-vector core `w = A·z − c·t1`

`MLDSA65_Verifier_v2._compute_w`:

- Computes `z_ntt = nttL(z)`.
- Optionally expands `c` into a challenge polynomial and moves it to NTT domain:
  - `c_poly = poly_challenge(dsig.c)`
  - `c_ntt = _nttPoly(c_poly)`
- For each row `k`:
  - Accumulate `Σ_j A_ntt[k, j] ∘ z_ntt[j]` in NTT domain.
  - If `c != 0`, subtract `c_ntt ∘ t1_ntt[k]` (also in NTT domain).
  - Apply inverse NTT to get `w[k]` back to the time domain.

Gas (from `MLDSA_MatrixVecGas.t.sol`):

- `w = A·z` (no challenge):  
  ~**524M gas**
- `w = A·z − c·t1` (with challenge):  
  ~**551M gas**

These numbers are for the current unoptimised reference implementation and are expected to go down with Montgomery arithmetic and other micro-optimisations.

---

## 6. `verify()` POC status

`MLDSA65_Verifier_v2.verify()` currently implements a **POC-level structural verifier**, not full FIPS-204.

Steps:

1. Basic structural checks:
   - `pk.raw.length >= 32`
   - `sig.raw.length >= 32`

2. Decode:
   - `DecodedPublicKey dpk = _decodePublicKey(pk)`
   - `DecodedSignature dsig = _decodeSignature(sig)`

3. Reject if `dsig.c == 0`  
   (real ML-DSA never uses a zero challenge seed).

4. Check a loose norm bound on `z`:
   - Uses `GAMMA1 = 2^19`, and currently enforces `|z_i| < GAMMA1` for all coefficients.
   - This mimics the `||z||∞ < γ₁` style constraint from FIPS-204 (without β yet).

5. Compute synthetic `w = A·z − c·t1` via `_compute_w`.

6. **FIPS-style challenge consistency:**
   - Reconstruct challenge polynomials from:
     - `dsig.c` (seed stored in the signature),
     - `message_digest` (external digest passed into `verify()`).
   - Compare:
     - `c_from_sig = poly_challenge(dsig.c)`
     - `c_from_msg = poly_challenge(message_digest)`
   - If these polynomials differ, reject the signature.

7. If all checks pass, return `true`.

Gas (from `MLDSA_VerifyGas.t.sol`):

- `verify() POC (decode + checks + w)`  
  ~**561M gas** total for a structurally valid test vector.

---

## 7. Roadmap (next steps)

High-level TODOs before calling this a “full” FIPS-204 verifier:

1. **Real FIPS-204 packing for full signatures**
   - Decode full ML-DSA-65 signature (z, h, and challenge seed) following the FIPS layout.
   - Ensure the current simplified layout stays supported for KAT / test-only paths, or confine it to a separate harness.

2. **Complete hint/decomposition path**
   - Implement proper decomposition `w1 = HighBits(w)` and hint reconstruction.
   - Wire `MLDSA65_Hint.applyHintL` into the verification flow.

3. **Final challenge computation**
   - Recreate the full FIPS challenge hash tree:
     - Include `mu`, `w1`, and all required components in the hash input.
   - Replace the current “two-seed” consistency check with a proper ML-DSA-style `c = H(mu, w1)`.

4. **Montgomery and gas optimisation**
   - Introduce Montgomery multiplication for polynomials:
     - Montgomery form for coefficients,
     - pre-converted NTT tables,
     - inline reduction instead of `mulmod`.
   - Target at least an order-of-magnitude gas reduction for NTT and `w` computation.

5. **More KAT coverage**
   - Add additional FIPS-204 KAT vectors for:
     - full verify(),
     - edge cases (small/large coefficients, boundary conditions).

---

## 8. How to run the test suite

From the project root:

```bash
forge test -vv


Selected subsets:

# Challenge helper
forge test -vv --match-contract MLDSA_FIPSChallenge_Test
forge test -vv --match-contract MLDSA_Challenge_Test

# Decode / packing
forge test -vv --match-contract MLDSA_Decode_Test
forge test -vv --match-contract MLDSA_FIPSPack_t1_Test

# NTT & matrix-vector
forge test -vv --match-contract NTT_MLDSA_Real_Test
forge test -vv --match-contract MLDSA_MatrixVec_Test
forge test -vv --match-contract MLDSA_MatrixVecGas_Test

# Verifier POC
forge test -vv --match-contract MLDSA_Verify_POC_Test
forge test -vv --match-contract MLDSA_VerifyGas_Test
