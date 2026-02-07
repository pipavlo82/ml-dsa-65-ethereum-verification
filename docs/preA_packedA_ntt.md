# PreA packedA_ntt calldata layout (ML-DSA-65 / FIPS-204 shape)

This repository supports a **PreA** fast-path where the verifier (or a helper runner)
receives a precomputed NTT-domain matrix `A_ntt` as calldata (`packedA_ntt`) and
computes `w = A·z − c·t1` (or an isolated `A·z` portion) without doing ExpandA+NTT on-chain.

## What is packedA_ntt?

`packedA_ntt` is a flat `bytes` blob encoding the ML-DSA-65 matrix `A` in the NTT domain.
It is intended for:
- ERC-7913 / AA adapters (`verifyWithPackedA(...)` style)
- protocol/system-level signature interfaces
- reproducible benchmarking (gas for `compute_w` from calldata)

## Encoding

- Matrix shape: **K×L = 6×5** polynomials (ML-DSA-65).
- Each polynomial has **256 coefficients**.
- Each coefficient is encoded as a **big-endian u32** (`u32be`).
- Layout is **poly-major**: polynomials are concatenated in order, each as 256×u32be.

### Polynomial order

`polyIndex = row * L + col`, with:
- `row` in `[0..K-1]` (K=6)
- `col` in `[0..L-1]` (L=5)

Total polynomials = `K*L = 30`.

### Size

- One polynomial: `256 * 4 = 1024` bytes
- Full matrix: `30 * 1024 = 30720` bytes

Therefore: `len(packedA_ntt) == 30720`.

## Reference implementation

- Decoder: `test/PreA_ComputeW_GasMicro.t.sol::_loadPolyU32be(...)`
- Builder: `test/PreA_ComputeW_GasMicro.t.sol::_buildPackedANtt(bytes32 rho)`
- On-chain runner: `script/RunPreAOnChain.s.sol`

## Notes

- This encoding is for *benchmarking + reproducible wiring*. It intentionally avoids
  compression so multiple projects can share one convention.
- Hash/XOF wiring is pinned separately (see the XOF vector suite in gas-per-secure-bit).
