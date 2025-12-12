# ML-DSA-65 Ethereum Verification

[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-tested-green)](https://getfoundry.sh/)
[![FIPS-204](https://img.shields.io/badge/FIPS--204-ML--DSA--65-purple)](https://csrc.nist.gov/pubs/fips/204/final)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Status:** Active development – FIPS-204 pipeline online, 64/64 tests passing  
**License:** MIT

---

## Overview

This repository implements and tests **FIPS 204 (ML-DSA-65)** post-quantum signature **verification** for Ethereum.

Goals:

- **FIPS-204–compatible on-chain verifier** for ML-DSA-65
- **ERC-7913 `IVerifier` integration** for wallets, AA, sequencers and rollups
- **Shared Keccak/SHAKE backend** aligned with existing Falcon / Dilithium EVM work
- **Canonical test & KAT harness** for ML-DSA-65 on Ethereum

The project is developed in coordination with the broader PQ ecosystem:

- **Falcon-1024:** [QuantumAccount](https://github.com/Cointrol-Limited/QuantumAccount) by [@paulangusbark](https://github.com/paulangusbark)
- **ETHDILITHIUM / ETHFALCON:** [ZKNoxHQ](https://github.com/ZKNoxHQ) by [@rdubois-crypto](https://github.com/rdubois-crypto)
- **Ethereum Foundation** researchers and EIP authors (e.g. EIP-8051 / EIP-8052)

The intent is to provide a **reference implementation** and **gas-profiled baseline** for ML-DSA-65 verification on EVM.

---

## High-Level Architecture

Conceptually, the verifier is layered as:

1. **Keccak / XOF backend (vendored from ZKNox)**
2. **Field & NTT layer (`q = 8,380,417`, `n = 256`)**
3. **Poly / PolyVec / Hint abstractions (ML-DSA-65 parameters: `k = 6`, `ℓ = 5`)**
4. **FIPS-204 parse & pack layer (public key, signature, t1, z, c, h)**
5. **ExpandA & challenge (synthetic + FIPS-shape Keccak variants)**
6. **Matrix–vector pipeline (`w = A·z − c·t1`)**
7. **Verifier v2 + ERC-7913 adapter**

All layers are covered by dedicated Foundry tests (unit, structural, KAT, and gas benchmarks).

---

## Implementation Status

### 1. Keccak / SHAKE backend (ZKNox)

Vendored from **ETHDILITHIUM** (ZKNox):

- `contracts/zknox_keccak/ZKNox_SHAKE.sol`  
  Canonical Keccak/SHAKE/XOF backend (F1600, SHAKE rate, absorb/squeeze).

- `contracts/zknox_keccak/ZKNox_KeccakPRNG.sol`  
  Keccak-CTR PRNG (`KeccakPRNG`) designed together with Zhenfei (Falcon co-author) during EF collaboration.

ML-DSA-65 uses this backend via a thin wrapper:

- `contracts/zknox_keccak/MLDSA65_KeccakXOF.sol`  
  - `struct Stream { bytes32 rho; uint8 row; uint8 col; KeccakPRNG prng; }`  
  - `initStream(rho, row, col)` – domain-separated XOF stream per `(rho,row,col)`  
  - `nextByte(Stream)` / `nextU16(Stream)` / `nextU32(Stream)`  
  - `expandA_stream(rho, row, col, outLen)` – generic XOF helper

**Tests**

- `test/MLDSA_KeccakXOF_Smoke.t.sol`
  - Determinism for fixed `(rho,row,col)`
  - Domain separation across rows / columns

All Keccak/SHAKE code from ZKNox is kept **bit-for-bit intact**, including headers and MIT license.

---

### 2. ExpandA (Keccak / FIPS-shape)

**Library**

- `contracts/verifier/MLDSA65_ExpandA_KeccakFIPS204.sol`

Provides a Keccak-based, FIPS-shape ExpandA building block:

- `expandA_poly(bytes32 rho, uint8 row, uint8 col) → int32[256]`
  - Uses `MLDSA65_KeccakXOF` streams
  - Samples `N = 256` coefficients from the ZKNox Keccak PRNG
  - Maps coefficients into a symmetric placeholder range around 0
    (to be tightened to the exact FIPS-204 bounds and rejection sampling)

- `expandA_matrix(bytes32 rho) → int32[6][5][256]` (shape: `[k][ℓ][N]`)
  - Deterministically builds the full matrix `A(rho)` by calling `expandA_poly`
    for each `(row, col)` pair

At this stage, the Keccak-based ExpandA is **shape-correct and deterministic**, but not yet locked to the exact bit-level FIPS-204 reference vectors. That alignment will happen once the CPU-side KATs for FIPS ExpandA are wired in.

**Tests**

- `test/MLDSA_ExpandA_Keccak_Smoke.t.sol`
  - `test_expandA_poly_deterministic`
  - `test_expandA_poly_separates_row_and_col`
  - `test_expandA_poly_coeffs_in_range`

- `test/MLDSA_ExpandA_Keccak_Matrix_Smoke.t.sol`
  - `test_expandA_matrix_deterministic`
  - `test_expandA_matrix_separates_row_and_col`

---

### 3. NTT layer (ML-DSA-65)

**Contracts**

- `contracts/ntt/NTT_MLDSA_Zetas.sol`  
  - Canonical Zetas table (`Q = 8,380,417`, `N = 256`), packed lookup.

- `contracts/ntt/NTT_MLDSA_Core.sol`  
  - NTT / INTT core (Cooley–Tukey butterflies, modular reductions).

- `contracts/ntt/NTT_MLDSA_Real.sol`  
  - Real NTT/INTT round-trip harness for `int32[256]` polynomials.

**Tests**

- `test/NTT_MLDSA_Structure.t.sol`  
  - Basis-vector roundtrips  
  - Random vector roundtrips  
  - Structural checks

- `test/NTT_MLDSA_Real.t.sol`  
  - Full NTT→INTT roundtrip gas and correctness

The NTT/INTT implementation is treated as **canonical** for downstream ML-DSA-65 work.  
Gas is currently unoptimized (correctness-first), with a dedicated optimization roadmap.

---

### 4. Poly / PolyVec / Hint layers

**Contracts**

- `contracts/verifier/MLDSA65_Poly.sol`
  - `add`, `sub`, `pointwiseMul` over `int32[256]` in `Z_q`
  - `Q = 8,380,417`, `N = 256`

- `contracts/verifier/MLDSA65_PolyVec.sol`
  - `PolyVecK` (k = 6) and `PolyVecL` (ℓ = 5)
  - Add/sub and NTT/INTT wrappers on top of `NTT_MLDSA_Real`

- `contracts/verifier/MLDSA65_Hint.sol`
  - Hint vector type `HintVecL`
  - `isValidHint`, `applyHintL` placeholder (shape-correct, semantics WIP)

**Tests**

- `test/MLDSA_Poly.t.sol`
- `test/MLDSA_PolyVec.t.sol`
- `test/MLDSA_Hint.t.sol`

All tests green; this layer forms the algebraic core for `t1`, `z`, `w`, and hint handling.

---

### 5. Decode & FIPS-204 pack layer

The v2 verifier artifacts expose **FIPS-204–compatible** decode for public keys and signatures:

- `contracts/verifier/MLDSA65_Verifier_v2.sol`
  - `DecodedPublicKey { bytes32 rho; PolyVecK t1; }`
  - `DecodedSignature { bytes32 c; PolyVecL z; HintVecL h; }`
  - FIPS-204 `t1` unpack:
    - 6 × 256 coefficients, 10-bit, from the first 1,920 bytes
  - Signature decode:
    - `z` coefficients (sequential 32-bit LE)
    - `c` from the last 32 bytes
    - Short signatures never revert (prefix decode behavior)

**Tests**

- `test/MLDSA_Decode.t.sol`  
- `test/MLDSA_DecodeCoeffs.t.sol`  
- `test/MLDSA_T1_KAT.t.sol`  

These tests verify:

- Length guards
- `rho`/`c` extraction
- Coefficient decoding for `t1` and `z`
- JSON-based FIPS KAT for `t1` (6×256)

---

### 6. Matrix–vector & synthetic `w = A·z − c·t1`

A synthetic matrix–vector layer is used to exercise the full pipeline:

- `contracts/verifier/MLDSA65_MatrixVec.sol` (naming may vary in repo, but conceptually:)
  - Bridges NTT layer, `PolyVecK`, `PolyVecL`, and `ExpandA`

- Computes a test-only:
  \[
    w = A·z − c·t1
  \]
  with a synthetic challenge polynomial and synthetic ExpandA (for legacy tests), plus Keccak-based tests via `MLDSA65_ExpandA_KeccakFIPS204`.

**Tests**

- `test/MLDSA_MatrixVec.t.sol`
- `test/MLDSA_MatrixVecGas.t.sol`
- `test/MLDSA_Verify_POC.t.sol`
- `test/MLDSA_VerifyGas.t.sol`
- `test/MLDSA_Verify_FIPSKAT.t.sol`
- `test/MLDSA_Signature_KAT.t.sol`
- `test/MLDSA_RealVector.t.sol`

These cover:

- Consistency of `w` with synthetic ExpandA vs unit-basis expand
- Interaction with FIPS-204 decode
- Gas benchmarks for `matrixvec_w` and POC `verify()`
- FIPS KAT “smoke” verify test on vector_001

---

### 7. Verifier v2 & ERC-7913 adapter

The main verifier entrypoints live in:

- `contracts/verifier/MLDSA65_Verifier_v2.sol`
  - ABI:
    - `verify(bytes32 messageHash, bytes calldata pubkey, bytes calldata signature) returns (bool)`
    - Internal use of decoded `t1`, `z`, `c`, hints and synthetic `w` pipeline
  - Current implementation is **structurally complete** and fully tested against:
    - Decode KATs
    - Real vector KAT
    - FIPS-style KAT (smoke verify)

- `contracts/erc7913/MLDSA65_ERC7913Verifier.sol`
  - Minimal adapter around `MLDSA65_Verifier_v2` implementing **ERC-7913 `IVerifier`**
  - Returns canonical 4-byte status code (e.g. `0xffffffff` for “ok”) and gas-profiled behavior

**Tests**

- `test/MLDSA_ERC7913Adapter.t.sol`
  - End-to-end check that ERC-7913 adapter calls into `MLDSA65_Verifier_v2`
    with FIPS KAT vector and returns the expected status code.

---

## Gas Overview (current ballpark)

All numbers are approximate and evolve as optimisations land, but current tests report:

- **NTT / INTT**
  - `NTT_MLDSA_Real` roundtrip basis: ~46M gas (correctness-first, unoptimised)
  - Random vectors: ~3M gas per roundtrip

- **Matrix–vector & `w`**
  - `matrixvec_w` gas tests: O(10⁸) gas (full FIPS-size buffers, POC)

- **Verify POC**
  - `MLDSA_VerifyGas.t.sol::test_verify_gas_poc()`: ~1.2×10⁸ gas

- **FIPS KAT verify**
  - `MLDSA_Verify_FIPSKAT_Test`: ~3.1M gas on the *structural* FIPS KAT harness  
    (this is not yet the final “full verification” gas number)

The gas model is intentionally conservative at this stage.  
Dedicated Yul-level and layout optimisations are planned once the FIPS-204 bit-level behavior is fully locked in.

---

## Repository Structure (simplified)

```text
ml-dsa-65-ethereum-verification/
│
├── contracts/
│   ├── ntt/
│   │   ├── NTT_MLDSA_Zetas.sol
│   │   ├── NTT_MLDSA_Core.sol
│   │   └── NTT_MLDSA_Real.sol
│   │
│   ├── zknox_keccak/
│   │   ├── ZKNox_SHAKE.sol             # SHAKE / Keccak backend (vendored)
│   │   ├── ZKNox_KeccakPRNG.sol        # Keccak-CTR PRNG (vendored)
│   │   └── MLDSA65_KeccakXOF.sol       # ML-DSA-65 XOF wrapper
│   │
│   ├── verifier/
│   │   ├── MLDSA65_Poly.sol
│   │   ├── MLDSA65_PolyVec.sol
│   │   ├── MLDSA65_Hint.sol
│   │   ├── MLDSA65_Challenge.sol
│   │   ├── MLDSA65_ExpandA.sol               # Synthetic ExpandA (legacy)
│   │   ├── MLDSA65_ExpandA_KeccakFIPS204.sol # Keccak/FIPS-shape ExpandA
│   │   ├── MLDSA65_MatrixVec.sol
│   │   └── MLDSA65_Verifier_v2.sol
│   │
│   ├── erc7913/
│   │   └── MLDSA65_ERC7913Verifier.sol
│   │
│   └── MontgomeryMLDSA.sol              # Montgomery R&D (kept for research)
│
├── test/
│   ├── NTT_MLDSA_Structure.t.sol
│   ├── NTT_MLDSA_Real.t.sol
│   ├── MLDSA_Poly.t.sol
│   ├── MLDSA_PolyVec.t.sol
│   ├── MLDSA_Hint.t.sol
│   ├── MLDSA_Challenge.t.sol
│   ├── MLDSA_Decode.t.sol
│   ├── MLDSA_DecodeCoeffs.t.sol
│   ├── MLDSA_T1_KAT.t.sol
│   ├── MLDSA_Signature_KAT.t.sol
│   ├── MLDSA_RealVector.t.sol
│   ├── MLDSA_StructuralParser.t.sol
│   ├── MLDSA_KeccakXOF_Smoke.t.sol
│   ├── MLDSA_ExpandA_Keccak_Smoke.t.sol
│   ├── MLDSA_ExpandA_Keccak_Matrix_Smoke.t.sol
│   ├── MLDSA_ExpandA_KAT_Test.t.sol
│   ├── MLDSA_MatrixVec.t.sol
│   ├── MLDSA_MatrixVecGas.t.sol
│   ├── MLDSA_Verify_POC.t.sol
│   ├── MLDSA_VerifyGas.t.sol
│   ├── MLDSA_Verify_FIPSKAT.t.sol
│   ├── MLDSA_ERC7913Adapter.t.sol
│   └── MontgomeryMLDSA.t.sol
│
├── test_vectors/
│   └── vector_001.json                 # FIPS-style KAT (NIST-compatible JSON)
│
├── scripts/
│   └── convert_vector.py               # Test vector tooling
│
└── research/
    └── README_MONTGOMERY.md            # Montgomery arithmetic R&D
Tests & KATs
Running tests
bash
Copy code
# All tests
forge test -vv

# NTT and field tests
forge test --match-contract NTT_MLDSA_Real_Test -vv
forge test --match-contract MontgomeryMLDSA_Test -vv

# Decode + FIPS pack
forge test --match-contract MLDSA_Decode_Test -vv
forge test --match-contract MLDSA_T1_KAT_Test -vv

# Keccak/XOF + ExpandA (Keccak/FIPS-shape)
forge test --match-contract MLDSA_KeccakXOF_Smoke_Test -vv
forge test --match-contract MLDSA_ExpandA_Keccak_Smoke_Test -vv
forge test --match-contract MLDSA_ExpandA_Keccak_Matrix_Smoke_Test -vv

# Matrix-vector and verify POC
forge test --match-contract MLDSA_MatrixVec_Test -vv
forge test --match-contract MLDSA_Verify_POC_Test -vv
forge test --match-contract MLDSA_Verify_FIPSKAT_Test -vv
forge test --match-contract MLDSA_ERC7913Adapter_Test -vv

# Gas benchmarks
forge test --match-contract MLDSA_MatrixVecGas_Test -vv
forge test --match-contract MLDSA_VerifyGas_Test -vv
Adding new KATs
Test vectors follow a NIST KAT–compatible JSON format:

json
Copy code
{
  "vector": {
    "name": "tv0_canonical",
    "message_hash": "0x...",
    "pubkey": {
      "raw": "0x...",
      "length": 1952
    },
    "signature": {
      "raw": "0x...",
      "length": 3309
    },
    "expected_result": true
  }
}
Place new vectors under:

text
Copy code
test_vectors/vector_XXX.json
and extend the corresponding *_KAT.t.sol to load and check them.

Roadmap
Short term
Wire Keccak-based ExpandA_poly / ExpandA_matrix into the main matrix-vector path.

Align the Keccak ExpandA and challenge XOF with the FIPS-204 reference implementation, up to full bit-level equality vs CPU KATs.

Promote Keccak-based ExpandA and challenge tests from “smoke” to strict KAT equality.

Medium term
Integrate real FIPS-204 poly_challenge into MLDSA65_Verifier_v2.

Implement full ML-DSA-65 verify() semantics (norm checks, hint application, etc.).

Tighten gas bounds for verify() and matrixvec_w POCs.

Long term
Yul-level and layout optimisation of NTT, PolyVec, and Keccak glue.

Cross-scheme gas comparison and “gas per secure bit” metrics (Falcon / Dilithium / ML-DSA-65).

Align with ERC-7913 and PQ verifier precompile discussions (e.g. EIP-8051 / EIP-8052).

Contributing
Contributions are welcome in:

ML-DSA / PQ cryptography and FIPS-204 conformance

EVM gas optimisation (Solidity / Yul)

NTT and modular arithmetic design

ERC-7913 / precompile standardisation

Please open issues or PRs and reference:

Relevant NIST / FIPS documents

Existing Falcon / Dilithium verifier work (ZKNox, QuantumAccount, etc.)

Any CPU-side reference implementations used for KAT generation

License
This project is licensed under the MIT License.
ZKNox Keccak / SHAKE backend files retain their original copyright headers and MIT license.

<div align="center">
Building quantum-resistant Ethereum verification for ML-DSA-65 🔐

</div> ```
