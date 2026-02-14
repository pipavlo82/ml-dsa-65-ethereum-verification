#!/usr/bin/env python3
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
src = ROOT / "contracts" / "ntt" / "NTT_MLDSA_Zetas.sol"
out = ROOT / "contracts" / "ntt" / "NTT_MLDSA_Zetas_New.sol"

text = src.read_text()

# Витягуємо всі числа з рядків `return XXXXX;`
vals = [int(m.group(1)) for m in re.finditer(r"return\s+(\d+);", text)]
if len(vals) != 256:
    raise SystemExit(f"Expected 256 zetas, found {len(vals)}")

def to_be32(x: int) -> str:
    # 32 байти big-endian → 64 hex символи
    return x.to_bytes(32, "big").hex()

hex_chunks = [to_be32(v) for v in vals]

# Робимо по одному значенню на рядок як окремий hex-literal
blob_lines = []
for h in hex_chunks:
    blob_lines.append(f'        hex"{h}"')

blob = ",\n".join(blob_lines)  # не важливо, кома між literals ігнорується

sol = f"""// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title NTT_MLDSA_Zetas
/// @notice Packed-table lookup for ML-DSA-65 NTT zetas (auto-generated)
/// @dev DO NOT EDIT BY HAND. Regenerate via scripts/gen_packed_zetas.py
library NTT_MLDSA_Zetas {{
    uint256 internal constant Q = 8380417;
    uint256 internal constant N = 256;
    uint256 internal constant N_INV = 8347681;

    /// @notice 256 zeta values packed as 8192 bytes (256 × 32 bytes)
    /// @dev Each value is 32-byte big-endian encoding
    bytes constant ZETAS_PACKED =
{chr(10).join(blob_lines)}
    ;

    /// @notice Get single zeta value by index
    /// @param i Index in range [0, 255]
    /// @return z Zeta value at index i
    function getZeta(uint256 i) internal pure returns (uint256 z) {{
        if (i >= 256) revert("Zeta index OOB");
        assembly {{
            let offset := mul(i, 32)
            z := mload(add(add(ZETAS_PACKED, 32), offset))
        }}
    }}
}}
"""

out.write_text(sol)
print(f"Wrote {out} with {len(vals)} zetas.")
