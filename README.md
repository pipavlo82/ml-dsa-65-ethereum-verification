ML-DSA-65 Ethereum Verification

Post-quantum verification for Solidity (FIPS-204, ML-DSA-65)

This repository provides the first minimal, auditable ML-DSA-65 (FIPS-204) verifier prototype for Ethereum.
It targets:

• L2 sequencers
• ERC-4337 AA bundlers
• Validator key-recovery flows
• Verifiable randomness consumers
• PQ migration paths for ECDSA-based systems

The repo includes Foundry test harnesses, real ML-DSA-65 signatures from an R4 entropy node, and a clean Solidity verifier scaffold intended for future full ML-DSA-65 verification.

Features
✓ ML-DSA-65 (FIPS-204) signature decoding

Full structure decoding pipeline:

• Base64 → bytes → ML-DSA-65 internal structure
• Length and domain checks
• Scheme sanity validation

Interoperable with R4 PQ-randomness API and reproducible test vectors.

✓ Solidity verification scaffold

solidity/IPQVerifier.sol contains:

• Signature length validation
• Public key length validation
• Scheme tag checks
• Message hashing via keccak256
• Stub for polynomial, NTT, challenge, hint verification

Designed to drop into existing PQ-ready designs such as QuantumAccount.

✓ Reproducible ML-DSA-65 test vectors (from R4)

Generated via the local R4 dual-signature randomness gateway:

curl -s "http://localhost:8082/random_dual?sig=pq" \
  -H "X-API-Key: demo" \
  > test_vectors/vector_001.json


Vectors include:

• random
• msg_hash
• ECDSA signature (v, r, s)
• ML-DSA-65 signature (Base64)
• ML-DSA-65 public key (Base64)
• scheme tag
• metadata

Stored under test_vectors/.

✓ Foundry tests

Two complete suites:

1) test/MLDSA_RealVector.t.sol
Parses real R4 PQ vectors (JSON + Base64 → struct).

2) test/MLDSA_Verify.t.sol
Exercises the Solidity verifier.

Covers the entire decoding + hashing pipeline up to verification logic.

Repository Structure
ml-dsa-65-ethereum-verification/
│
├── solidity/
│   ├── MLDSA65Verifier.sol        # reference verifier
│   └── IPQVerifier.sol            # integration scaffold
│
├── test/
│   ├── MLDSA_RealVector.t.sol     # parses real R4 vectors
│   └── MLDSA_Verify.t.sol         # verifier pipeline test
│
├── test_vectors/
│   ├── README.md
│   └── vector_001.json
│
├── scripts/
│   ├── decode_vectors.py
│   ├── decode_real_pq.py
│   └── mldsa65_sign.py (optional)
│
├── foundry.toml
└── docs/
    └── spec.md

Generating Real ML-DSA-65 Vectors (R4 Node)

Ensure your R4 gateway is running at:

http://localhost:8082


Generate a reproducible PQ vector:

curl -s "http://localhost:8082/random_dual?sig=pq" \
  -H "X-API-Key: demo" \
  > test_vectors/vector_001.json


Note: Browsers cannot call this endpoint because it requires the header X-API-Key: demo.

Running Tests

Install dependencies:

forge install foundry-rs/forge-std --no-commit


Run full suite:

forge test -vvv


Run PQ vector test only:

forge test -vvv --match-test test_real_vector


Expected output:

[PASS] test_real_vector()
[PASS] test_verify_pq_signature()

Solidity Integration (QuantumAccount Example)
1. Message hashing (Ethereum domain)

ML-DSA-65 uses SHAKE256 for the challenge,
but Solidity implementations typically use keccak256 for L1/L2 domain separation.

bytes32 msgHash = keccak256(
    abi.encodePacked(domain, payload)
);

2. Verification inside IPQVerifier
require(sig.length == EXPECTED_SIG_LEN, "invalid signature length");
require(pub.length == EXPECTED_PK_LEN,  "invalid public key length");
require(scheme == MLDSA65,             "wrong PQ scheme");

// TODO: polynomial + NTT + hint + challenge verification

3. Hybrid mode (ECDSA + ML-DSA-65)

Supports:

• Classical ECDSA verification
• ML-DSA-65 verification
• Dual-signature flows for VRF or validator proof-of-control

Ideal for AA wallets, sequencer proofs, and VRF-based apps.

Roadmap
A) Full ML-DSA-65 Solidity Verifier

Implement polynomial arithmetic:

• NTT
• Hint bits
• Challenge construction
• Norm constraints

Goal: full FIPS-204 compatibility.

B) Gas Benchmarks

Baseline expectations (pre-optimization):

• Falcon-1024: 10–12M gas
• ML-DSA-65: 18–22M gas

Goal: ZK-friendly optimizations and polynomial commitment reuse.

C) PQ Verification ABI Standard

Equivalent of OpenZeppelin’s ECDSA.sol for post-quantum signatures.

Targets contract-level standardization for PQ-ready AA wallets and L2 clients.

Contributing

PRs welcome for:

• NTT gas optimization
• In-Solidity SHAKE128/256
• Polynomial algebra
• Falcon vs ML-DSA-65 comparison
• ERC-4337 integration templates

License

MIT License.
