#!/usr/bin/env python3
"""
gen_expandA_fips_kat.py

Utility to generate CPU-side KATs for FIPS-204 ExpandA(rho) for ML-DSA-65.

⚠️ IMPORTANT:
This script is a scaffold. You MUST plug in a real FIPS-204 compliant
ML-DSA-65 implementation to compute A(rho). The goal here is to standardize:

- how we call the reference,
- how we serialize the matrix A(rho),
- where we store JSON KATs for the Solidity tests.
"""

import json
import os
from pathlib import Path
from typing import List

# ML-DSA-65 parameters
K = 6       # rows
L = 5       # cols
N = 256     # poly length
Q = 8380417 # modulus


# =========================
# 1) PLACEHOLDER REFERENCE
# =========================

def expandA_reference(rho: bytes) -> List[List[List[int]]]:
    """
    Compute the full A(rho) matrix for ML-DSA-65 using a *real* FIPS-204
    implementation.

    MUST return a 3D list of shape [K][L][N], with each entry an int in [0, Q).

    This function is intentionally left as a placeholder. You should:
    - either import an existing Python ML-DSA-65 implementation, OR
    - wrap a CLI tool that prints A(rho) in a parseable format.

    For now we just raise, so you don’t accidentally rely on a fake implementation.
    """
    raise NotImplementedError(
        "expandA_reference(rho) is not implemented. "
        "Plug in a real FIPS-204 ExpandA(rho) implementation here."
    )


# =========================
# 2) JSON SERIALIZATION
# =========================

def matrix_to_json(rho_hex: str, A: List[List[List[int]]]) -> dict:
    """
    Serialize A(rho) matrix into a JSON structure that Solidity tests can load.

    Layout:
    {
      "vector": {
        "name": "expandA_rho_xxx",
        "rho": "0x...",
        "params": { "k":6, "l":5, "n":256, "q":8380417 },
        "A": [
          [  # row 0
            [a_0_0[0], ..., a_0_0[255]],   # col 0
            ...,
            [a_0_4[0], ..., a_0_4[255]]    # col 4
          ],
          ...,
          [  # row 5
            ...                            # 5x polys
          ]
        ]
      }
    }
    """
    if len(A) != K:
        raise ValueError(f"A must have {K} rows, got {len(A)}")
    for row in A:
        if len(row) != L:
            raise ValueError(f"Each row must have {L} cols")
        for poly in row:
            if len(poly) != N:
                raise ValueError(f"Each poly must have {N} coeffs")
            for c in poly:
                if not (0 <= c < Q):
                    raise ValueError(f"Coefficient {c} out of range [0,{Q})")

    return {
        "vector": {
            "name": f"expandA_{rho_hex[2:10]}",
            "rho": rho_hex,
            "params": {
                "k": K,
                "l": L,
                "n": N,
                "q": Q,
            },
            "A": A,
        }
    }


# =========================
# 3) MAIN
# =========================

def main() -> None:
    """
    Simple driver:

    - Reads rho from env or uses a hardcoded demo value.
    - Calls expandA_reference(rho) to get A(rho).
    - Writes JSON to test_vectors/expandA_<rho_prefix>.json.
    """

    # 1) Get rho
    rho_hex = os.getenv(
        "MLDSA_EXPANDA_RHO",
        # Default: just a demo seed – replace with true KAT rho later
        "0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
    )
    if rho_hex.startswith("0x"):
        rho_bytes = bytes.fromhex(rho_hex[2:])
    else:
        rho_bytes = bytes.fromhex(rho_hex)

    if len(rho_bytes) != 32:
        raise ValueError(f"rho must be 32 bytes, got {len(rho_bytes)}")

    # 2) Call reference implementation (you must implement this)
    A = expandA_reference(rho_bytes)

    # 3) Serialize to JSON
    data = matrix_to_json(rho_hex if rho_hex.startswith("0x") else "0x" + rho_hex, A)

    # 4) Write file
    out_dir = Path("test_vectors")
    out_dir.mkdir(parents=True, exist_ok=True)

    out_path = out_dir / f"expandA_{rho_hex[2:10]}.json"
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

    print(f"[ok] Wrote ExpandA KAT to {out_path}")


if __name__ == "__main__":
    main()
