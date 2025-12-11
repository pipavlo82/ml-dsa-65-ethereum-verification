#!/usr/bin/env python3
import json
from pathlib import Path

# Параметри ML-DSA-65
Q = 8380417
K = 6
N = 256
PK_LEN = 1920 + 32  # t1_packed (1920) + rho (32)


def fake_mldsa65_keygen():
    """
    Тимчасова заглушка: генерує псевдо-pk.
    1920 байт t1_packed + 32 байти rho.
    """
    pk_bytes = bytes((i % 256 for i in range(PK_LEN)))
    sk_bytes = b""
    return pk_bytes, sk_bytes


def fake_mldsa65_unpack_pk(pk_bytes: bytes):
    """
    Тимчасовий псевдо-UNPACK, який імітує Solidity _decodeT1Packed.

    ВАЖЛИВО: тут ми повторюємо ту саму 4×10→5 байт схему, що й у
    MLDSA65_Verifier_v2::_decodeT1Packed, щоб JSON-вектор і on-chain
    декод збігалися один з одним.
    """
    assert len(pk_bytes) == PK_LEN
    src = pk_bytes[:1920]

    t1 = []

    for k in range(K):
        poly = [0] * N
        base = k * 320  # 320 байт на поліно́м

        for g in range(64):  # 64 групи по 4 коефіцієнти
            idx = base + 5 * g

            b0 = src[idx + 0]
            b1 = src[idx + 1]
            b2 = src[idx + 2]
            b3 = src[idx + 3]
            b4 = src[idx + 4]

            t0 = (b0 | ((b1 & 0x03) << 8)) & 0x03FF
            t1c = ((b1 >> 2) | ((b2 & 0x0F) << 6)) & 0x03FF
            t2c = ((b2 >> 4) | ((b3 & 0x3F) << 4)) & 0x03FF
            t3c = ((b3 >> 6) | (b4 << 2)) & 0x03FF

            base_coeff = 4 * g
            poly[base_coeff + 0] = t0
            poly[base_coeff + 1] = t1c
            poly[base_coeff + 2] = t2c
            poly[base_coeff + 3] = t3c

        t1.append(poly)

    rho = pk_bytes[-32:]

    return rho, t1


def main():
    out_path = Path("vectors/mldsa65_t1_kat_001.json")

    # 1) Генеруємо псевдо-pk
    pk_bytes, _ = fake_mldsa65_keygen()

    # 2) Розпаковуємо t1 тим самим FIPS-правилом
    rho, t1_coeffs = fake_mldsa65_unpack_pk(pk_bytes)

    # 3) Перевірки довжин
    assert len(pk_bytes) == PK_LEN
    assert len(t1_coeffs) == K
    for j in range(K):
        assert len(t1_coeffs[j]) == N

    # 4) Готуємо JSON
    data = {
        "name": "mldsa65_t1_kat_001",
        "pubkey": "0x" + pk_bytes.hex(),   # t1_packed || rho
        "rho": "0x" + rho.hex(),
        "t1": t1_coeffs,                   # 6×256 int
    }

    out_path.write_text(json.dumps(data, indent=2))
    print(f"[+] Written {out_path}")


if __name__ == "__main__":
    main()
