# Keccak / SHAKE backend (ZKNox ETHDILITHIUM)

This repository reuses the Keccak / SHAKE / XOF backend from **ETHDILITHIUM (ZKNox)** as
the canonical hash / XOF layer for ML-DSA-65 on Ethereum.

## Origin

Vendored files (bit-for-bit identical to upstream):

- `contracts/zknox_keccak/ZKNox_SHAKE.sol`
- `contracts/zknox_keccak/ZKNox_KeccakPRNG.sol`

Upstream project:

- ETHDILITHIUM (ZKNOX) – Dilithium-on-Ethereum implementation

License: MIT (see upstream `LICENSE` and headers in the vendored files).

## How it is used here

On top of the ZKNox backend we add a thin ML-DSA–oriented wrapper:

- `contracts/zknox_keccak/MLDSA65_KeccakXOF.sol`

This wrapper provides:

- `Stream` – XOF stream state derived from `(rho, row, col)`
- `initStream(rho, row, col)` – derive a per-(rho,row,col) stream
- `nextByte / nextU16 / nextU32` – typed pulls from the stream
- `expandA_stream(rho, row, col, outLen)` – generic FIPS-style stream helper

Currently this wrapper is only used in:

- `test/MLDSA_KeccakXOF_Smoke.t.sol` – determinism & domain-separation smoke tests

## Planned use (FIPS-204)

In follow-up PRs this backend will be used to implement:

- A FIPS-204–compatible `ExpandA(rho)` for ML-DSA-65
- A SHAKE-based `poly_challenge` / challenge XOF

The goal is to keep:

- **Crypto core** (Keccak / SHAKE / PRNG) aligned with ZKNox ETHDILITHIUM
- **Interfaces** aligned with ERC-7913 (`IVerifier`)
- ML-DSA-65–specific logic (NTT, matrix–vector, bounds, hints) in this repo.
