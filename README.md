# ML-DSA-65 Ethereum Verification

**Status:** Active Development – Foundation Complete, Cryptography In Progress  
**License:** MIT

## Overview

Reference implementation and test infrastructure for **FIPS 204 (ML-DSA-65)** post-quantum signature verification on Ethereum.

**Focus areas:**
- **Standardization:** Algorithm-agnostic `IPQVerifier` interface
- **FIPS 204 compliance:** Strict adherence to NIST formats
- **Working implementation:** Structural parser complete
- **Test infrastructure:** Real test vectors + NIST KAT-compatible format
- **Ecosystem alignment:** Coordinated with Falcon-1024 and Dilithium developers

This repository contributes to the broader effort to define PQ signature verification standards for Ethereum, alongside:
- **Falcon-1024:** [@paulangusbark's QuantumAccount](https://github.com/Cointrol-Limited/QuantumAccount)
- **ETHDILITHIUM / ETHFALCON:** [@rdubois-crypto's implementations](https://github.com/ZKNoxHQ)

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

This parser provides the foundation for cryptographic verification.

### 🔄 Cryptographic Verification (In Progress)

**Next implementation steps:**
- [ ] NTT (Number Theoretic Transform)
- [ ] Polynomial arithmetic over Z_q
- [ ] Challenge re-computation
- [ ] Norm constraint checking
- [ ] Signature validity pipeline

**Target:** 7–9M gas for complete ML-DSA-65 verification

---

## Repository Structure
```
ml-dsa-65-ethereum-verification/
│
├── solidity/
│   ├── IPQVerifier.sol              # PQ verification interface (draft)
│   └── MLDSA65Verifier.sol          # Structural ML-DSA parser (complete)
│
├── test/
│   ├── MLDSA_StructuralParser.t.sol # Structural + gas tests
│   └── MLDSA_RealVector.t.sol       # End-to-end vector tests
│
├── test_vectors/
│   └── vector_001.json              # Real PQ test vector
│
├── scripts/
│   └── convert_vector.py            # Test vector utilities
│
└── docs/
    └── STANDARDIZATION.md           # (coming soon)
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
- Unified API for Falcon, Dilithium, ML-DSA
- Composable primitives for wallets, AA, sequencers
- Fair cross-algorithm gas benchmarking

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

**Current status:** All tests passing ✅
## Adding New Test Vectors

Test vectors follow a **NIST KAT-compatible JSON format**.

**To contribute new vectors:**

1. **Generate ML-DSA-65 signature** using any FIPS 204-compliant implementation:
   - Python `cryptography` or `pycryptodome`
   - Rust `pqcrypto` crate
   - C reference implementation
   - Any compliant library

2. **Format requirements:**
   - Public key: 1,952 bytes (hex-encoded)
   - Signature: 3,309 bytes (hex-encoded)
   - Message hash: 32 bytes, hex with `0x` prefix

3. **Use canonical schema:**
```json
   {
     "vector": {
       "name": "custom_vector_001",
       "message_hash": "0x48656c6c6f576f726c64...",
       "pubkey": {
         "raw": "0x1a2b3c4d...",
         "length": 1952
       },
       "signature": {
         "raw": "0x5e6f7a8b...",
         "length": 3309
       },
       "expected_result": true
     }
   }
```

4. **Save as:** `test_vectors/vector_XXX.json`

5. **Validate:**
```bash
   forge test -vvv --match-test real
```

**Conversion utility:**
```bash
python3 scripts/convert_vector.py input.json output.json
```

This reformats raw vectors into the canonical schema.

**Vector contributions welcome!** Open a PR or issue to add ML-DSA-65 test vectors for cross-validation.
---

## Calldata Comparison

| Component  | Falcon-1024 | ML-DSA-65 | Difference |
|------------|-------------|-----------|------------|
| Public key | 1,793 B     | 1,952 B   | +9%        |
| Signature  | ~1,330 B    | ~3,309 B  | +149%      |
| **Total**  | **~3,123 B**| **~5,261 B** | **+68%** |

**Trade-offs:**
- **ML-DSA:** Deterministic, FIPS-certified, larger calldata
- **Falcon:** Compact, but uses rejection sampling

Both algorithms serve different ecosystem needs.

---

## Gas Model

| Scheme                     | Gas Cost | Status      |
|----------------------------|----------|-------------|
| Structural parser (current)| ~235k    | ✅ Complete  |
| **ML-DSA-65 (full)**       | **7–9M** | 🔄 In progress |
| Falcon-1024                | ~10M     | Reference   |
| ETHDILITHIUM               | 6.6M     | Reference   |

**Estimate basis:**
- 6–8 NTT operations on 256-coefficient polynomials
- SHAKE256 hashing over expanded state
- Norm constraint checking
- Calldata processing overhead

---

## Roadmap

### Phase 1: Foundation ✅ (Complete)
- [x] Interface design
- [x] Structural parser
- [x] Test vectors
- [x] Gas framework

### Phase 2: Cryptographic Verification 🔄 (Ongoing)
- [ ] NTT implementation
- [ ] Polynomial arithmetic
- [ ] Challenge verification
- [ ] Norm constraints

### Phase 3: Optimization
- [ ] Yul assembly optimization
- [ ] Memory management
- [ ] Benchmarking vs Falcon/Dilithium

### Phase 4: Standardization
- [ ] Standardization document
- [ ] Community review
- [ ] EIP draft

---

## Contributing

We welcome contributions in:
- PQ cryptography implementation
- EVM gas optimization
- NTT / polynomial arithmetic
- Cross-validation with other PQ schemes
- Standardization review

**Coordination with:**
- [@paulangusbark](https://github.com/paulangusbark)
- [@rdubois-crypto](https://github.com/rdubois-crypto)
- [@seresistvanandras](https://ethresear.ch/u/seresistvanandras) (Ethereum Foundation)

**Discussion:** [EthResear.ch thread](https://ethresear.ch/t/the-road-to-post-quantum-ethereum-transaction-is-paved-with-account-abstraction/21277)

---

## References

### Standards
- **FIPS 204:** [ML-DSA Standard](https://csrc.nist.gov/pubs/fips/204/final)

### Ethereum Improvement Proposals
- **EIP-8051:** [ML-DSA Verification](https://ethereum-magicians.org/t/eip-8051-ml-dsa-verification/18752)
- **EIP-8052:** [Falcon Support](https://ethereum-magicians.org/t/eip-8052-precompile-for-falcon-support/18740)

### Related Implementations
- **Falcon-1024:** [QuantumAccount](https://github.com/Cointrol-Limited/QuantumAccount) (~10M gas)
- **Dilithium:** [ETHDILITHIUM](https://github.com/ZKNoxHQ/ETHDILITHIUM) (6.6M gas)
- **Falcon (optimized):** [ETHFALCON](https://github.com/ZKNoxHQ/ETHFALCON) (2M gas)

---

## License

MIT License
