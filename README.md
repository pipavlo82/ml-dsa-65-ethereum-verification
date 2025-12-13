# ML-DSA-65 Ethereum Verification

[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-tested-green)](https://getfoundry.sh/)
[![FIPS-204](https://img.shields.io/badge/FIPS--204-ML--DSA--65-purple)](https://csrc.nist.gov/pubs/fips/204/final)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Status:** Active Development – Foundation Complete, Cryptography In Progress  
**License:** MIT

---

## Overview

Reference implementation and test infrastructure for **FIPS 204 (ML-DSA-65)** post-quantum signature verification on Ethereum.

**Focus areas:**
- **Standardization:** Algorithm-agnostic `IPQVerifier` interface  
- **FIPS 204 compliance:** Strict adherence to NIST formats  
- **Working implementation:** Structural parser complete  
- **Test infrastructure:** Real test vectors + NIST KAT-compatible format  
- **Ecosystem alignment:** Coordinated with Falcon-1024 and Dilithium developers  

This repository contributes to the broader effort to define PQ verification standards for Ethereum, alongside:

- **Falcon-1024:** [QuantumAccount](https://github.com/Cointrol-Limited/QuantumAccount) by [@paulangusbark](https://github.com/paulangusbark)  
- **ETHDILITHIUM / ETHFALCON:** [ZKNoxHQ implementations](https://github.com/ZKNoxHQ) by [@rdubois-crypto](https://github.com/rdubois-crypto)

---

## Implementation Status

### ✅ Structural ML-DSA-65 Parser (Complete)

`MLDSA65Verifier.sol` includes full structural decoding:

**Validation:**
- Public key size: **1,952 bytes**
- Signature size: **3,309 bytes**

**Parsing:**
- `c_tilde` challenge  
- 256 × `z_i` coefficients (int32)  
- Hint bits vector `h`  
- Domain separation computation  

**Gas measurements:**
```
Structural parsing: ~235,085 gas
Full test suite:    ~259,259 gas
```

This parser forms the foundation for cryptographic verification logic.

### Status

This repository tracks an experimental on-chain verifier for ML-DSA-65 (FIPS-204).

Current milestones:

- ✅ Montgomery / Barrett field arithmetic & gas benchmarks
- ✅ Structural verifier for real ML-DSA-65 test vector (off-chain KAT, v1 parser)
- 🧪 Stable NTT layer for ML-DSA-65 (PR #2: "Stable ML-DSA-65 NTT Implementation")
- 🧪 Verifier core skeleton: Poly / PolyVec / Hint layers (PR #3)
- 🧪 Pack/coeff decoding layer for t1 / z (PR #4)
- 🧪 FIPS-204 t1 packed decode + synthetic `w = A·z − c·t1` layer on top of the v2 verifier (PR #5)

The NTT, verifier core, and pack/FIPS layers are intentionally kept in feature branches and open PRs until the full verification pipeline is validated.

The NTT, verifier core, and pack layer are intentionally kept in feature branches and open PRs until the full verification pipeline is validated.

### Open ML-DSA-65 verifier milestones (PR #2 / #3 / #4 / #5)

**PR #2 – Stable ML-DSA-65 NTT Implementation (All Tests Passing, Finalized Classic Zetas)**

Stable ML-DSA-65 NTT/INTT implementation based on the classic `NTT_MLDSA_Zetas.sol` table.

- All NTT structure tests, random roundtrips and basis-vector checks pass.
- No recursion issues, no MemoryOOG.

Current gas profile:
- NTT: ~2.7M gas
- INTT: ~2.6M gas
- Full NTT→INTT: ~5.3M gas

Acts as the canonical NTT core for later verifier work.

---

**PR #3 – ML-DSA-65 verifier core: Poly / PolyVec / Hint layers, decode harness, v2 skeleton**

- Polynomial helpers over \( \mathbb{Z}_q \) with \( q = 8,380,417 \).
- `PolyVecL` (ℓ = 5) and `PolyVecK` (k = 6) with add/sub and NTT/INTT wrappers on top of `NTT_MLDSA_Real`.
- Hint layer skeleton: `HintVecL`, `isValidHint`, `applyHintL` placeholder.

`MLDSA65_Verifier_v2` skeleton:

- Public key / signature wrappers:  
  `struct PublicKey { bytes raw; }`, `struct Signature { bytes raw; }`
- Decoded views:
  - `DecodedPublicKey { bytes32 rho; PolyVecK t1; }`
  - `DecodedSignature { bytes32 c; PolyVecL z; HintVecL h; }`
- `_decodePublicKey` / `_decodeSignature` overloads for both struct and raw-byte callers, with length guards.
- `verify()` ABI in place, currently returning `false` by design (cryptographic checks not yet wired).

Full Foundry harness for poly, polyvec, hint, decode, and skeleton verification.

---

**PR #4 – Synthetic pack layer: byte→coeff decoding for t1 / z + tests**

- Adds `_decodeCoeffLE(bytes data, uint256 offset)` helper (4-byte little-endian, mod q) inside `MLDSA65_Verifier_v2`.
- Extends `_decodePublicKey` / `_decodeSignature` to:
  - preserve existing length guards,
  - read `rho` / `c` from the last 32 bytes,
  - read the first few coefficients of `t1[0]` and `z[0]` from the leading bytes (synthetic layout).
- New Foundry test `MLDSA_DecodeCoeffs.t.sol` checking byte→coeff mapping for `t1[0][0..3]` and `z[0][0..3]`.

Uses a **synthetic** layout for t1/z; not FIPS-204-compliant by design. No public ABI changes. Intended as an intermediate pack layer to bootstrap KAT generation and byte-level tests.

---

**PR #5 – FIPS-204 t1 packed decode + synthetic matrix–vector layer (current feature branch)**  
<https://github.com/pipavlo82/ml-dsa-65-ethereum-verification/pull/5>

- Full public key decode:
  - FIPS-204 compatible `t1` unpack (6×256, 10-bit) from the first 1,920 bytes,
  - `rho` from the last 32 bytes of the 1,952-byte public key.
- Full signature decode:
  - `z` as a `PolyVecL` (sequential 32-bit LE coefficients),
  - `c` from the last 32 bytes,
  - short signatures never revert (prefix-only decode).
- NTT bridges and tests for `PolyVecL` / `PolyVecK` via `NTT_MLDSA_Real` (roundtrip basis vectors + random vectors).
- Synthetic `ExpandA` + matrix–vector layer computing a **test-only**
  `w = A·z − c·t1` on chain (using a synthetic challenge polynomial and synthetic `ExpandA`).
- End-to-end “real vector KAT” harness and matrix/PolyVec NTT tests keep **all 43/43 Foundry tests green** on this feature branch.

> **Out of scope for PR #5**  
> PR #5 intentionally does **not** implement:
> - the real FIPS-204 `ExpandA` (SHAKE256-based XOF and rejection sampling),
> - the official `poly_challenge` construction,
> - coefficient decomposition / hint application logic,
> - or a full ML-DSA-65 `verify()` routine.
>
> These components will be introduced in follow-up PRs once the packing / decoding / NTT and synthetic  
> `w = A·z − c·t1` layers are fully settled and reviewed.

### 🔄 Cryptographic Verification (In Progress)

Next implementation steps:

- [ ] NTT (Number Theoretic Transform) integration into verifier pipeline
- [ ] Polynomial arithmetic over Z_q
- [ ] Challenge recomputation
- [ ] Norm constraint checking
- [ ] Full signature verification pipeline

Target: 7–9M gas for full ML-DSA-65 verification (based on Dilithium/Falcon benchmarks)

---

## 🔬 Research Notes

This repository includes a dedicated research section documenting low-level arithmetic experiments, benchmarking, and optimization strategies for ML-DSA-65 verification on EVM.

### Current Research Highlight

**Montgomery Arithmetic for ML-DSA-65** — correctness, benchmarks, and gas analysis

The study covers:

- ✅ Full Montgomery implementation for the ML-DSA-65 field
- ✅ Equivalence proof against mulmod
- ✅ 200+ correctness test cases
- ✅ Polynomial multiplication benchmarks (256-coeff workloads)
- ✅ Gas comparison: Montgomery vs native mulmod
- ✅ Practical implications for NTT design
- ⚠️ Why Montgomery is not gas-efficient for small modulus q≈2²³
- ✅ Recommended optimization strategy for the real ML-DSA verifier

**Barrett reduction** (experimental, rejected)

- Multiple Barrett variants evaluated (64-bit style and 256-bit style)
- No clear gas advantage over native mulmod for q ≈ 2²³
- Added complexity and correctness risks for 256-bit inputs
- Conclusion: treated as R&D only; production path will rely on mulmod

### 📄 Detailed Research Document

➡️ `research/README_MONTGOMERY.md`

This report guides the design of the upcoming NTT, Barrett reduction module, and overall gas-optimization strategy for ML-DSA-65 on EVM.

---

## Repository Structure
```
ml-dsa-65-ethereum-verification/
│
├── contracts/
│   ├── MontgomeryMLDSA.sol          # Montgomery R&D implementation
│   └── MLDSA65Verifier.sol          # Structural parser (complete)
│
├── test/
│   ├── MontgomeryMLDSA.t.sol        # Correctness + gas benchmarks
│   ├── MLDSA_StructuralParser.t.sol # Parsing + gas tests
│   └── MLDSA_RealVector.t.sol       # End-to-end vector tests
│
├── test_vectors/
│   └── vector_001.json              # PQ test vector (canonical format)
│
├── scripts/
│   └── convert_vector.py            # Test vector utilities
│
└── research/
    └── README_MONTGOMERY.md         # Montgomery arithmetic R&D report
```

---

## IPQVerifier Interface (Draft)

A proposed unified interface for post-quantum signature verification:
```solidity
interface IPQVerifier {
    function verify(
        bytes memory message,
        bytes memory signature,
        bytes memory publicKey
    ) external view returns (bool);

    function verifyBatch(
        bytes[] memory messages,
        bytes[] memory signatures,
        bytes memory publicKey
    ) external view returns (bool[] memory);

    function algorithmName() external pure returns (string memory);

    function expectedSizes() external pure returns (
        uint256 pkSize,
        uint256 sigSize
    );
}
```

**Goals:**

- Unified wallet/AA/sequencer integration
- Cross-algorithm benchmarking (Dilithium, Falcon, ML-DSA)
- Standardized precompile discussions

---

## Test Vectors

### JSON Format (NIST-compatible)
```json
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
```

### Running Tests
```bash
# All tests
forge test -vvv

# Structural parser tests
forge test -vvv --match-test structural

# Real vector tests
forge test -vvv --match-test real
```

### Adding New Test Vectors

**Requirements:**

- PK = 1,952 bytes (hex)
- Signature = 3,309 bytes (hex)
- Message_hash = 32 bytes

**Save vectors as:**
```bash
test_vectors/vector_XXX.json
```

**Validate with:**
```bash
forge test -vvv --match-test real
```

---

## Calldata Comparison

| Component | Falcon-1024 | ML-DSA-65 | Difference |
|-----------|-------------|-----------|------------|
| Public key | 1,793 B | 1,952 B | +9% |
| Signature | ~1,330 B | 3,309 B | +149% |
| Total | ~3,123 B | 5,261 B | +68% |

---

## Gas Model

| Scheme | Gas Cost | Status |
|--------|----------|--------|
| Structural parser (current) | ~235k | ✅ Complete |
| ML-DSA-65 (full) | 7–9M | 🔄 In progress |
| Falcon-1024 | ~10M | Reference |
| ETHDILITHIUM | 6.6M | Reference |

---

## Roadmap

### Phase 1: Foundation ✅ (Complete)

- [x] Interface design
- [x] Structural parser
- [x] Test vectors
- [x] Gas framework

### Phase 2: Cryptographic Verification 🔄 (Ongoing)

- [ ] NTT
- [ ] Polynomial arithmetic
- [ ] Challenge verification
- [ ] Norm constraints

### Phase 3: Optimization 📋

- [ ] Yul-level optimization
- [ ] Memory layout improvements
- [ ] Benchmarking vs Falcon/Dilithium

### Phase 4: Standardization 📋

- [ ] STANDARDIZATION.md
- [ ] Community review
- [ ] EIP draft

---

## NTT layer (PR #2)

An experimental ML-DSA-65 NTT/INTT implementation is available in the open PR:

**PR #2 – "Stable ML-DSA-65 NTT Implementation (All Tests Passing, Finalized Classic Zetas)"**

**Key points:**

- Dimension: n = 256, modulus q = 8380417 (Dilithium / ML-DSA-65 parameter set).

**Contracts:**

- `contracts/ntt/NTT_MLDSA_Core.sol` – NTT/INTT core (butterflies, Montgomery domain).
- `contracts/ntt/NTT_MLDSA_Real.sol` – test harness and round-trip wiring.

**Tests:**

- `test/NTT_MLDSA_Structure.t.sol` – structural tests (basis vectors, random vectors).
- `test/NTT_MLDSA_Real.t.sol` – gas and round-trip tests.

The NTT code is considered cryptographically correct (round-trip tests, basis vectors, structure tests all passing) but is still in a separate branch for further gas optimisation and independent review before merging into main.

---

## Contributing

We welcome contributions in:

- ✅ PQ cryptography
- ✅ EVM gas optimization
- ✅ NTT / polynomial arithmetic
- ✅ Standardization review

**Coordination with:**

- [@paulangusbark](https://github.com/paulangusbark) - Falcon-1024
- [@rdubois-crypto](https://github.com/rdubois-crypto) - ETHDILITHIUM/ETHFALCON
- Ethereum Foundation researchers

**Discussion:** [EthResear.ch thread](https://ethresear.ch)

---

## References

### Standards

- [FIPS 204 - ML-DSA Standard](https://csrc.nist.gov/pubs/fips/204/final)

### Ethereum Improvement Proposals

- [EIP-8051 - ML-DSA Verification](https://eips.ethereum.org/EIPS/eip-8051)
- [EIP-8052 - Falcon Support](https://eips.ethereum.org/EIPS/eip-8052)

### Related Implementations

- [QuantumAccount](https://github.com/Cointrol-Limited/QuantumAccount) - Falcon-1024 (~10M gas)
- [ETHFALCON](https://github.com/ZKNoxHQ/ETHFALCON) - Falcon-512 (2M gas)
- [ETHDILITHIUM](https://github.com/ZKNoxHQ/ETHDILITHIUM) - Dilithium (6.6M gas)

---

## License

MIT License

**Research:** [ethresear.ch](https://ethresear.ch)

---

<div align="center">

**Building quantum-resistant Ethereum infrastructure 🔐**

</div>





