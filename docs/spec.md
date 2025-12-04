# ML-DSA-65 — Raw Signature & Public Key Specification (Ethereum-Focused)

This document defines the canonical byte-level layout for ML-DSA-65 signatures
and public keys as used in the Ethereum verification project.  
The goal is reproducibility, compatibility with Cointrol/Falcon research, and
a deterministic interface for Foundry benchmarking.

---

## 1. Public Key Structure (canonical ML-DSA-65)

ML-DSA-65 public keys are encoded as:

pk = rho || t1

yaml
Copy code

Where:

| Field | Size | Description |
|-------|------|-------------|
| `rho` | 32 bytes | seed for polynomial generation |
| `t1`  | variable (~1920 bytes) | polynomial vector in compressed form |

Canonical encoded size: **1952 bytes**

---

## 2. Signature Structure (canonical ML-DSA-65)

Raw signature layout:

signature = salt || polyvec

yaml
Copy code

Where:

| Field | Size | Description |
|--------|------|-------------|
| `salt` | 32 bytes | per-signature random value |
| `polyvec` | variable (~3277 bytes) | z-vector and hints |

Canonical size: **3309 bytes** for ML-DSA-65.

No headers, no ASN.1, no metadata.

This matches the layout used by Cointrol and Falcon-EVM work.

---

## 3. Ethereum Hash Binding

The message digest used for verification:

mu = keccak256( rho || message )

markdown
Copy code

Reasoning:
- deterministic domain separation  
- resistant to preimage substitution  
- consistent with Falcon-EVM hash discipline  
- matches AA wallet replay protection scheme

---

## 4. Required Verification Steps

A conformant ML-DSA-65 EVM verifier must:

1. Parse:
   - `salt`
   - `z` vector (polynomials)
   - `h` hint bits  
2. Recompute `mu`
3. Validate the polynomial bounds
4. Perform NTT/INTT transitions
5. Reconstruct:
   - `t0 + t1`
6. Verify:

A * z - t0 ≡ c * s1 (mod q)

yaml
Copy code

All polynomial operations use the same modulus and NTT parameters defined in
FIPS-204.

---

## 5. Deterministic Test Vector Format

Test vectors stored in:

test_vectors/mldsa65_kat.json

arduino
Copy code

Structure:

```json
{
  "vectors": [
    {
      "name": "tv0",
      "message": "0x...",
      "pubkey": "0x...",
      "signature": "0x...",
      "expected": true
    }
  ]
}
6. Gas Benchmark Model
Two gas-test modes:

1. verify() cold-call mode
Simulates L2 sequencer usage.

2. verify() warm-call mode
Simulates AA wallets (ERC-4337).

Results written automatically via Foundry traces.

7. Notes
This repository intentionally mirrors Falcon-EVM design.

ML-DSA-65 has different polynomial decomposition (t0/t1), but layout is compatible with the benchmarking harness.

Stub verifier in Solidity matches this spec and is replaced later with real logic.

End of Document.
