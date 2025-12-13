q = 8380417
psi = 1753  # ML-DSA-65 root parameter from FIPS-204

def modexp(a, e, m):
    return pow(a, e, m)

# ω = ψ^2 mod q  (256-th primitive root)
omega = modexp(psi, 2, q)

# Generate forward roots in bit-reversed order
roots = [0] * 256
for i in range(256):
    roots[i] = modexp(omega, i, q)

# Inverse roots
inv_omega = modexp(omega, q - 2, q)
inv_roots = [modexp(inv_omega, i, q) for i in range(256)]

# N inverse
INV_N = pow(256, q - 2, q)

print("omega =", omega)
print("inv_omega =", inv_omega)
print("INV_N =", INV_N)
print("---- forward roots ----")
print(roots)
print("---- inverse roots ----")
print(inv_roots)
