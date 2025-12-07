# ML-DSA-65 Ethereum Verification

**Status:** Work in Progress – Standardization Focus  
**License:** MIT

## Overview

Reference implementation and test infrastructure for **FIPS 204 (ML-DSA-65)** 
post-quantum signature verification on Ethereum, with emphasis on:

- **Standardization:** Algorithm-agnostic `IPQVerifier` interface
- **FIPS 204 compliance:** Strict adherence to NIST standard
- **Test infrastructure:** NIST KAT-compatible test vectors
- **Ecosystem coordination:** Alignment with Falcon-1024 and Dilithium work

This is part of broader community effort to establish post-quantum signature 
standards for Ethereum, coordinated with:
- **Falcon-1024:** [@paulangusbark's QuantumAccount](https://github.com/Cointrol-Limited/QuantumAccount)
- **ETHDILITHIUM/ETHFALCON:** [@rdubois-crypto's implementations](https://github.com/ZKNoxHQ)

## Goals

1. **Interface standardization** – Unified `IPQVerifier` for Falcon/Dilithium/ML-DSA
2. **FIPS 204 reference** – Byte-for-byte NIST standard compliance
3. **Test vector library** – NIST KAT-compatible, cross-implementation validation
4. **Gas benchmarking** – Methodology for fair algorithm comparison

**This is not "Falcon vs ML-DSA"** – it's establishing shared infrastructure 
for multiple PQ algorithms to coexist on Ethereum.

---

## Repository Structure
```
ml-dsa-65-ethereum-verification/
│
├── solidity/
│   ├── IPQVerifier.sol          # Standardized PQ interface
│   └── MLDSA65Verifier.sol      # ML-DSA-65 reference (WIP)
│
├── test/
│   ├── MLDSA_RealVector.t.sol   # Test vector parsing
│   └── MLDSA_Verify.t.sol       # Verification pipeline
│
├── test_vectors/
│   ├── README.md
│   └── mldsa65_kat_example.json # NIST KAT format
│
├── scripts/
│   ├── decode_vectors.py
│   └── mldsa65_sign.py          # Test vector generator
│
└── docs/
    ├── comparison.md             # Falcon vs ML-DSA analysis
    └── STANDARDIZATION.md        # Interface spec (coming)
```

---

## IPQVerifier Interface (Draft)

Proposed standardized interface for post-quantum signatures:
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

**Design goals:**
- Works across Falcon-1024, ML-DSA-65, and future PQ schemes
- Enables composable PQ primitives for protocols/wallets
- Consistent gas benchmarking across implementations

Inspired by OpenZeppelin patterns for classical signatures.

---

## Test Vectors

### Format (NIST KAT-compatible)
```json
{
  "description": "ML-DSA-65 canonical test vector",
  "vector": {
    "name": "tv0_canonical",
    "message": "0x48656c6c6f",
    "pubkey": {
      "raw": "0x...",
      "length": 1952,
      "format": "canonical-ml-dsa-65"
    },
    "signature": {
      "raw": "0x...",
      "length": 3309,
      "format": "canonical-ml-dsa-65"
    },
    "expected_result": true
  }
}
```

### Usage

Generate test vectors:
```bash
python scripts/mldsa65_sign.py --kat-format
```

Run Foundry tests:
```bash
forge test -vvv --match-test test_real_vector
```

---

## Current Status

- [x] `IPQVerifier` interface draft
- [x] Test vector format specification
- [x] Comparative analysis (Falcon vs ML-DSA)
- [ ] Full `MLDSA65Verifier` implementation (NTT, polynomial ops)
- [ ] Gas benchmarking results
- [ ] Standardization proposal document

---

## Calldata Comparison

| Component     | Falcon-1024 | ML-DSA-65 | Difference |
|---------------|-------------|-----------|------------|
| Public key    | 1,793 B     | 1,952 B   | +9%        |
| Signature     | ~1,330 B    | ~3,309 B  | +149%      |
| Total calldata| ~3,123 B    | ~5,261 B  | +68%       |

**Implication:** ML-DSA has larger calldata footprint but offers:
- Deterministic signing (no rejection sampling)
- FIPS 204 standardization (Aug 2024)
- Simpler security proofs (module-LWE)

**Trade-off:** Both algorithms serve different needs – Falcon for compact 
signatures, ML-DSA for regulatory compliance.

---

## Gas Model (Preliminary Estimates)

Based on complexity analysis and comparison with existing implementations:

| Implementation      | Expected Gas  | Notes                        |
|---------------------|---------------|------------------------------|
| Falcon-1024         | ~10M gas      | Measured (@paulangusbark)    |
| ETHDILITHIUM        | 6.6M gas      | Measured (@rdubois-crypto)   |
| **ML-DSA-65 (est.)** | **7M-9M gas** | Model-based, pending implementation |

**Factors:**
- 6-8 NTT operations on 256-element polynomials
- SHAKE256 hashing over larger state
- Calldata parsing overhead

**Note:** These are model-based projections. Actual implementation in progress.

---

## Roadmap

### Phase 1: Standardization (Current)
- [x] Interface design
- [x] Test vector format
- [ ] Standardization proposal document
- [ ] Community review (EthResear.ch)

### Phase 2: Reference Implementation
- [ ] Full NTT implementation
- [ ] Polynomial arithmetic
- [ ] Challenge construction
- [ ] Norm constraints

### Phase 3: Validation
- [ ] Gas benchmarking
- [ ] Cross-validation with ETHDILITHIUM
- [ ] NIST KAT test suite
- [ ] EIP draft proposal

---

## Contributing

This is a **standardization effort** for the Ethereum ecosystem.

### Areas for Contribution

1. **Test vectors** – Add NIST KAT-compatible vectors
2. **Gas optimization** – Share techniques from your implementations
3. **Interface design** – Suggest improvements to `IPQVerifier`
4. **Cross-validation** – Test against Falcon/Dilithium implementations

### Coordination

Active coordination with:
- [@paulangusbark](https://github.com/paulangusbark) (Falcon-1024)
- [@rdubois-crypto](https://github.com/rdubois-crypto) (ETHDILITHIUM/ETHFALCON)

Discussion: [EthResear.ch thread](link-when-posted)

---

## Use Cases (Ecosystem-Wide)

Post-quantum signature verification enables:
- **AA wallets** – ERC-4337 with PQ security
- **L2 sequencers** – Quantum-safe validator rotation
- **Key recovery** – PQ-safe backup mechanisms
- **Verifiable randomness** – PQ-VRF implementations
- **Compliance** – FIPS 204-mandated environments

**This repository focuses on infrastructure**, not specific applications.

---

## References

- **FIPS 204:** [ML-DSA Standard](https://csrc.nist.gov/pubs/fips/204/final)
- **EIP-8051:** [ML-DSA verification (draft)](https://ethereum-magicians.org/t/eip-8051-ml-dsa-verification/18752)
- **EIP-8052:** [Falcon precompile (draft)](https://ethereum-magicians.org/t/eip-8052-precompile-for-falcon-support/18740)
- **Related work:**
  - [QuantumAccount](https://github.com/Cointrol-Limited/QuantumAccount) (Falcon-1024)
  - [ETHDILITHIUM](https://github.com/ZKNoxHQ/ETHDILITHIUM)
  - [ETHFALCON](https://github.com/ZKNoxHQ/ETHFALCON)
-
  

## License

MIT License
