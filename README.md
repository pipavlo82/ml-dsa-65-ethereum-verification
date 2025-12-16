# ML-DSA-65 Ethereum Verification (FIPS-204 shape)

[![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.20-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-tested-green)](https://getfoundry.sh/)
[![FIPS-204](https://img.shields.io/badge/FIPS--204-ML--DSA--65-purple)](https://csrc.nist.gov/pubs/fips/204/final)
[![ERC-7913](https://img.shields.io/badge/ERC--7913-Signature%20Verifiers-6f42c1)](https://eips.ethereum.org/EIPS/eip-7913)
[![Tests](https://img.shields.io/badge/Tests-89%2F89%20passing-brightgreen)]()
[![Gas](https://img.shields.io/badge/Gas-verify__poc%20~68.9M-orange)]()
[![Gas](https://img.shields.io/badge/Gas-PreA__packedA__compute__w%20~1.50M-orange)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Status:** Active development. End-to-end `verify()` **POC** + full gas harness. Foundry suite green.  
**Latest gas (snapshot):** `test_verify_gas_poc = 68,901,612` gas (logged verify POC ≈ `68,158,524`).  
**PreA milestone:** packed `A_ntt` calldata microbench for `compute_w` ≈ **1,499,354** gas (rho0/rho1).  
**Phase12:** ERC-7913 adapters + `verifyWithPackedA(...)` path (calldata `packedA_ntt`) + tests & gas microbenches.

> This repo is research / standardization work. Not audited. Do not use in production.

---

## Table of Contents

- [Overview](#overview)
- [What’s implemented](#whats-implemented)
- [Gas benchmarks](#gas-benchmarks)
- [Build & test](#build--test)
- [Repo layout](#repo-layout)
- [Design notes](#design-notes)
- [Roadmap](#roadmap)
- [Competitors / related PQ/EVM work](#competitors--related-pqevm-work)
- [Security](#security)
- [License](#license)

---

## Overview

This repository implements an **ML-DSA-65 (FIPS-204 shape)** verification pipeline in **Solidity**, targeting:

- A clean, auditable on-chain verifier baseline (research + standardization)
- **ERC-7913-style** signature verifier adapters (wallets, AA, sequencers, rollups)
- Reproducible **KAT-style** tests and deterministic **gas snapshots**
- A realistic path to reduce the dominant cost:

$$
w = A \cdot z - c \cdot t1
$$

**Standards / context**
- **FIPS-204 (ML-DSA):** https://csrc.nist.gov/pubs/fips/204/final  
- **ERC-7913 (Signature Verifiers):** https://eips.ethereum.org/EIPS/eip-7913  
- **EIP-8051 (ML-DSA verification discussion):** https://ethereum-magicians.org/t/eip-8051-ml-dsa-verification/25857  
- **EIP-8052 (Falcon precompile):** https://eips.ethereum.org/EIPS/eip-8052  

---

## What’s implemented

### Core crypto pipeline (FIPS-204 shape)

- **Keccak/SHAKE backend (vendored)** + thin ML-DSA XOF wrapper
- **NTT/INTT** for ML-DSA modulus/degree:
  - \( q = 8,380,417 \)
  - \( n = 256 \)
- Poly / PolyVec / Hint scaffolding for ML-DSA-65 shape:
  - \( k = 6 \) (t1)
  - \( \ell = 5 \) (z, h)
- FIPS-shaped decode for pubkey/signature (t1 / z / c) + KAT coverage
- Matrix-vector core:

$$
w = A \cdot z - c \cdot t1
$$

- `MLDSA65_Verifier_v2` end-to-end **verify() POC** (decode + checks + compute_w)

### ERC-7913 integration

- `MLDSA65_ERC7913Verifier` adapter implementing ERC-7913-style verification
- `MLDSA65_ERC7913BoundCommitA` (CommitA binding flow) to prevent matrix substitution when using precomputed A
- Phase12 fast-path:
  - `verifyWithPackedA(...)` accepts calldata **packed `A_ntt`**
  - Adapter tests + bound-commit tests
  - Gas microbench harness

### PreA track (performance isolation)

PreA isolates the hot loop and shows what’s achievable when `A_ntt` is supplied efficiently:

- calldata-friendly **packed `A_ntt`** format (loader)
- **microbench:** compute `w` from packed `A_ntt` in isolation
- Commitment binding helper (CommitA) to prevent swapping `A`

---

## Gas benchmarks

All numbers are from Foundry tests + `.gas-snapshot`.

| Component | Gas | Where |
|---|---:|---|
| verify() POC (snapshot) | 68,901,612 | `MLDSA_VerifyGas_Test:test_verify_gas_poc()` |
| verify() POC (log) | ~68,158,524 | same test logs |
| compute_w breakdown | see logs | `MLDSA_VerifyGasBreakdown_Test` |
| **PreA** `compute_w_fromPacked_A_ntt` | **1,499,354** | `PreA_ComputeW_GasMicro_Test` |
| ERC-7913 `verifyWithPackedA` (micro) | ~71,796 | `MLDSA_ERC7913_PackedA_GasMicro.t.sol` |

Key point: end-to-end verifier is dominated by `compute_w` (matrix-vector core).  
PreA demonstrates what the hot loop can look like when `A_ntt` is supplied efficiently.

---

## Build & test

### Build

```bash
forge build
```

### Run all tests

```bash
forge test -vv
```

### Focused runs (recommended)

```bash
# verify() POC gas
forge test --match-test test_verify_gas_poc -vv

# breakdown (decode + compute_w)
forge test --match-contract MLDSA_VerifyGasBreakdown_Test -vv

# PreA packed A_ntt microbench
forge test --match-contract PreA_ComputeW_GasMicro_Test -vv

# MatrixVec correctness + gas
forge test --match-contract MLDSA_MatrixVec_Test -vv
forge test --match-contract MLDSA_MatrixVecGas_Test -vv

# ERC-7913 packedA adapter tests
forge test --match-contract MLDSA_ERC7913_PackedA_Test -vv

# Update .gas-snapshot
forge snapshot
```

---

## Repo layout

Typical structure (names may evolve, but intent stays stable):

- `contracts/`
  - `verifier/` — `MLDSA65_Verifier_v2.sol`, ERC-7913 adapters, bound-commit flow
  - `ntt/` — NTT/INTT + zetas tables (ML-DSA q = 8,380,417)
  - vendored SHAKE/Keccak backend
  - `poly/` — Poly / PolyVec / Hint helpers (FIPS shape)
- `test/`
  - decode tests + JSON KAT tests
  - gas harnesses (verify POC, breakdown, matrixvec gas, PreA micro)
  - ERC-7913 adapter tests
- `test_vectors/`
  - JSON KAT-style vectors (pubkey / signature / message-hash)
- `.gas-snapshot`
- `foundry.toml`
- `README.md`, `PQ-NOTES.MD`

---

## Design notes

### Why ERC-7913

ERC-7913 generalizes signature verification beyond “address-only” signatures (EOA / ERC-1271), which is important for PQ keys.

- Spec: https://eips.ethereum.org/EIPS/eip-7913

OpenZeppelin interface docs mention the expected magic values:
- valid: `IERC7913SignatureVerifier.verify.selector`
- invalid: `0xffffffff` or revert

- OZ interfaces docs: https://docs.openzeppelin.com/contracts/5.x/api/interfaces

### Why CommitA binding (when using packed A)

If we accept a precomputed `A_ntt` from calldata, we must prevent an attacker from swapping the matrix.
CommitA binding is a lightweight “bind A to rho / context” mechanism for the fast-path.

---

## Roadmap

Short-term (next practical steps):

1. Wire PreA fast-path into `MLDSA65_Verifier_v2`
   - guarded by CommitA binding
   - keep legacy path for reference correctness

2. Tighten end-to-end FIPS-204 conformance
   - challenge derivation, sampling details, KAT equality checks
   - keep the repo FIPS-shaped and test-vector-driven

3. Push down `compute_w` gas
   - inner-loop reductions (fewer loads/stores)
   - unrolling / batching
   - minimize memory roundtrips in NTT domain

4. Standardization packaging
   - ERC-7913 “drop-in verifier” shape
   - canonical JSON KAT pipeline
   - reproducible benches + “gas per secure bit” methodology (separate workstream)

---

## Competitors / related PQ/EVM work

### PQ signature Solidity implementations / research

- **ZKNoxHQ — ETHDILITHIUM:** https://github.com/ZKNoxHQ/ETHDILITHIUM  
- **ZKNoxHQ — ETHFALCON:** https://github.com/ZKNoxHQ/ETHFALCON  
- **Falcon + AA discussion (FalconSimpleWallet demo mentioned):**  
  https://ethresear.ch/t/the-road-to-post-quantum-ethereum-transaction-is-paved-with-account-abstraction-aa/21783

### Standardization / ecosystem direction

- **ERC-7913:** https://eips.ethereum.org/EIPS/eip-7913  
- **EIP-8051 discussion:** https://ethereum-magicians.org/t/eip-8051-ml-dsa-verification/25857  
- **EIP-8052:** https://eips.ethereum.org/EIPS/eip-8052  

---

## Security

- Not audited. Research-quality code.
- Main risk surfaces:
  - calldata-supplied `A_ntt` path (must be bound/committed)
  - decode correctness (FIPS packing/unpacking)
  - domain separation (hash/XOF wiring)
- This repo is designed to be test-vector-first and gas-bench reproducible.

---

## License

MIT (see `LICENSE`).  
Vendored Keccak/SHAKE files retain their original headers and license terms.
