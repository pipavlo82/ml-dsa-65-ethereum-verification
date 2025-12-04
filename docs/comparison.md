# Falcon-1024 vs ML-DSA-65 (Ethereum-Oriented Comparison)

This document provides a side-by-side comparison of Falcon-1024 and ML-DSA-65
focusing on calldata footprint, verification complexity, and expected gas costs.

---

## 1. Calldata Size

| Component | Falcon-1024 | ML-DSA-65 |
|----------|--------------|-----------|
| Public key | 1793 bytes | 1952 bytes |
| Signature  | ~1330 bytes | ~3309 bytes |
| Total calldata | ~3123 bytes | ~5261 bytes |

ML-DSA input is ~1.68× larger.

---

## 2. Verification Complexity

| Step | Falcon-1024 | ML-DSA-65 |
|------|-------------|------------|
| Polynomial dimension | 1024 | 512 |
| NTT/INTT operations | Required | Required |
| Challenge generation | SHAKE256 | SHAKE256 |
| Hint structure | light | heavier |
| Lattice basis | FFT | NTT |

ML-DSA is **more predictable**, Falcon more **fragile numerically**.

---

## 3. Expected Gas (pure Solidity prototype)

| Mode | Falcon-1024 | ML-DSA-65 |
|------|-------------|------------|
| Cold-call | 5.5M–7.2M | 7M–9M |
| Warm-call | 3.8M–5M | 5M–6.5M |

---

## 4. Ethereum Suitability

- Falcon: fits better into precompiles; FFT unfriendly for Solidity  
- ML-DSA-65: more stable, predictable, deterministic; easier to standardize  
- Both designs converge around SHAKE + lattice ops + NTT-friendly structure  

---

This repo standardizes **ML-DSA calldata & ABI** for future PQ-EVM research.
