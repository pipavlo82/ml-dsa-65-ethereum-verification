#!/usr/bin/env python3
import json
import pathlib

Q = 8380417
N = 256
L = 5
SIG_BYTES = 3309  # FIPS-204 сигнатура має 3309 байт, ми просто дотримуємось розміру


def main() -> None:
    # Візьмемо прості коефіцієнти для z[0][0..3]
    z0_coeffs = [0, 1, 2, 3]

    # Готуємо байтовий буфер під сигнатуру
    sig = bytearray(SIG_BYTES)

    # 1) Запаковуємо z[0][0..3] у перші 16 байтів як 4× int32 LE
    #    Це відповідає поточному `_decodeSignatureRaw`, який читає:
    #    z[0][i] = _decodeCoeffLE(sigRaw, i * 4) для i in 0..3.
    for i, c in enumerate(z0_coeffs):
        v = c % Q
        off = 4 * i
        sig[off:off + 4] = int(v).to_bytes(4, "little", signed=False)

    # 2) Заповнюємо "тіло" (байти між 16 та останніми 32) якимось детермінованим патерном
    for i in range(4 * len(z0_coeffs), SIG_BYTES - 32):
        sig[i] = i % 256

    # 3) Останні 32 байти = c (challenge), беремо простий патерн 0x80..0x9f
    c_bytes = bytes(range(0x80, 0x80 + 32))
    sig[-32:] = c_bytes

    # 4) Формуємо повний z як PolyVecL (L = 5, N = 256)
    z = []
    row0 = z0_coeffs + [0] * (N - len(z0_coeffs))
    z.append(row0)
    for _ in range(L - 1):
        z.append([0] * N)

    # 5) h – поки що просто нулі, placeholder
    h = []
    for _ in range(L):
        h.append([0] * N)

    out = {
        "name": "mldsa65_sig_kat_001",
        "sig": "0x" + sig.hex(),
        "c": "0x" + c_bytes.hex(),
        "z": z,
        "h": h,
    }

    path = pathlib.Path("vectors/mldsa65_sig_kat_001.json")
    path.write_text(json.dumps(out, indent=2))
    print(f"[+] Written {path}")


if __name__ == "__main__":
    main()
