#!/usr/bin/env python3
# Generates KAT vectors for Solidity NTT implementation
# Fully standalone: computes its own zetas, NTT, INTT

Q = 8380417
N = 256
OMEGA = 1753   # Dilithium primitive root

# Bit-reversal for Dilithium indexing
def bit_reverse(x, bits):
    y = 0
    for _ in range(bits):
        y = (y << 1) | (x & 1)
        x >>= 1
    return y

# Generate full 256-entry zeta table (same as Solidity NTT_MLDSA_Zetas)
def generate_zetas():
    zetas = [0] * 256
    zetas[0] = 1
    for i in range(1, 256):
        zetas[i] = pow(OMEGA, bit_reverse(i, 8), Q)
    return zetas

zetas = generate_zetas()

# Forward NTT (Cooley–Tukey, decimation-in-time)
def ntt(a):
    a = a.copy()
    k = 1
    for length in [128, 64, 32, 16, 8, 4, 2, 1]:
        for start in range(0, N, 2 * length):
            z = zetas[k]
            k += 1
            for j in range(start, start + length):
                t = (a[j + length] * z) % Q
                u = a[j]
                a[j]        = (u + t) % Q
                a[j+length] = (u - t) % Q
    return a

# Inverse NTT (Gentleman–Sande, decimation-in-frequency)
def intt(a):
    a = a.copy()
    k = 255
    length = 1
    while length < N:
        for start in range(0, N, 2 * length):
            z = zetas[k]
            k -= 1
            for j in range(start, start + length):
                u = a[j]
                v = a[j + length]
                a[j]        = (u + v) % Q
                a[j+length] = ((u - v) * z) % Q
        length *= 2

    # Multiply by N^{-1} mod Q
    N_INV = pow(N, Q - 2, Q)
    for i in range(N):
        a[i] = (a[i] * N_INV) % Q
    return a

# Test input vector
a = [(i * 17 + 123) % Q for i in range(N)]
ntt_a = ntt(a)
intt_back = intt(ntt_a)

# Print Solidity arrays
print("uint256[256] memory KAT_INPUT = [")
for v in a:
    print(f"    {v},")
print("];\n")

print("uint256[256] memory KAT_NTT = [")
for v in ntt_a:
    print(f"    {v},")
print("];\n")

print("uint256[256] memory KAT_INTT = [")
for v in intt_back:
    print(f"    {v},")
print("];")
