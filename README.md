# ML-DSA-65 Ethereum Verification (FIPS-204 shape)

[![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.20-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-tested-green)](https://getfoundry.sh/)
[![FIPS-204](https://img.shields.io/badge/FIPS--204-ML--DSA--65-purple)](https://csrc.nist.gov/pubs/fips/204/final)
[![Tests](https://img.shields.io/badge/Tests-86%2F86%20passing-brightgreen)]()
[![Gas](https://img.shields.io/badge/Gas-verify__poc%20~68.9M-orange)]()
[![Gas](https://img.shields.io/badge/Gas-PreA__packedA__compute__w%20~1.50M-orange)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Status:** Active development. End-to-end `verify()` **POC** + full gas harness. Foundry suite green (**86/86**).  
**Latest gas (snapshot):** `test_verify_gas_poc = 68,901,612` gas (logged verify POC ≈ `68,158,524`).  
**PreA milestone:** packed `A_ntt` calldata microbench for `compute_w` ≈ **1,499,354** gas (rho0/rho1).

---

## Overview

This repository implements and tests an **ML-DSA-65 (FIPS-204 shape)** verification pipeline in **Solidity**, targeting:

- A clean, auditable on-chain verifier baseline (research + standardization)
- **ERC-7913-style verifier adapter** (wallets, AA, rollups, sequencers)
- Reproducible **KAT-style** tests and **gas snapshots**
- A realistic path to reduce the dominant cost: `w = A·z − c·t1`

Related PQ/EVM work:
- Falcon-1024: QuantumAccount by @paulangusbark
- ETHDILITHIUM / ETHFALCON: ZKNoxHQ by @rdubois-crypto
- EF discussions/EIPs (EIP-8051 / EIP-8052 context)

---

## What’s implemented

- **Keccak/SHAKE backend (vendored)** + thin ML-DSA XOF wrapper
- **NTT/INTT (q = 8,380,417, n = 256)** + correctness + gas microbenches
- Poly / PolyVec / Hint scaffolding for ML-DSA-65 shape (`k=6`, `ℓ=5`)
- FIPS-shaped decode for pubkey/signature (t1/z/c) + KAT coverage
- Matrix-vector core:
  \[
    w = A \cdot z - c \cdot t1
  \]
- **Verifier v2 POC** + **ERC-7913 adapter**
- **Phase11 PreA track**
  - `packed A_ntt` format (calldata-friendly)
  - `CommitA` binding helper to prevent matrix substitution
  - Microbench: `compute_w` from packed `A_ntt` in isolation

---

## Gas benchmarks (measured)

| Component | Gas | Where |
|---|---:|---|
| `verify()` POC (snapshot) | 68,901,612 | `MLDSA_VerifyGas_Test:test_verify_gas_poc()` |
| `verify()` POC (log) | ~68,158,524 | same test logs |
| `compute_w` breakdown | see breakdown logs | `MLDSA_VerifyGasBreakdown_Test` |
| **PreA** `compute_w_fromPacked_A_ntt` | **1,499,354** | `PreA_ComputeW_GasMicro_Test` |

Key point: end-to-end verifier is still dominated by `compute_w` (matrix-vector core). PreA isolates the hot loop and shows what’s achievable when `A_ntt` is supplied efficiently.

---

## Build & test

### Build
```bash
forge build
Run all tests
bash
Copy code
forge test -vv
Focused runs (recommended)
bash
Copy code
# verify() POC gas
forge test --match-test test_verify_gas_poc -vv

# breakdown (decode + compute_w)
forge test --match-contract MLDSA_VerifyGasBreakdown_Test -vv

# PreA packed A_ntt microbench
forge test --match-contract PreA_ComputeW_GasMicro_Test -vv

# MatrixVec correctness + gas
forge test --match-contract MLDSA_MatrixVec_Test -vv
forge test --match-contract MLDSA_MatrixVecGas_Test -vv

# Update .gas-snapshot
forge snapshot
Progress (recent)
Phase11: PreA packed A_ntt + CommitA binding
Added calldata-friendly packed A_ntt format and loader

Added CommitA binding helper (prevents matrix substitution attacks when using precomputed A)

Added PreA_ComputeW_GasMicro harness

All tests green (86/86)

Roadmap (short)
Wire PreA fast-path into Verifier_v2 (guarded by CommitA binding)

Tighten FIPS-204 conformance end-to-end (challenge, sampling, KAT equality)

Keep pushing down compute_w gas (inner-loop reductions, unrolling, fewer loads/stores)

Standardization packaging (ERC-7913 shape + canonical JSON KAT pipeline)

License
MIT. Vendored ZKNox Keccak/SHAKE files retain original headers and license.
