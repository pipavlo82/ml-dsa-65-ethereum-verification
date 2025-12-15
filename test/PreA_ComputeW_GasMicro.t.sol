// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import { MLDSA65_ExpandA_KeccakFIPS204 } from "../contracts/verifier/MLDSA65_ExpandA_KeccakFIPS204.sol";
import { NTT_MLDSA_Real } from "../contracts/ntt/NTT_MLDSA_Real.sol";

/// @dev Runner робимо окремим контрактом, щоб bytes пішли саме через calldata.
contract PreA_ComputeW_Runner {
    uint256 internal constant Q = 8380417;
    uint256 internal constant K = 6;
    uint256 internal constant L = 5;

    // -------------------------
    //  Tiny deterministic PRNG
    // -------------------------
    function _randVec(uint256 seed) internal pure returns (uint256[256] memory r) {
        unchecked {
            uint256 x = seed;
            for (uint256 i = 0; i < 256; ++i) {
                // xorshift64-ish (дешево)
                x ^= (x << 13);
                x ^= (x >> 7);
                x ^= (x << 17);
                r[i] = x % Q;
            }
        }
    }

    // -------------------------
    //  Decode packed A_ntt poly
    // -------------------------
    // Format: K*L polys, each poly = 256 uint32 big-endian, total poly bytes = 256*4 = 1024.
    // packed layout index = row*L + col (row in [0..5], col in [0..4])
    function _loadPolyU32be(bytes calldata packed, uint256 polyIndex, uint256[256] memory out) internal pure {
        unchecked {
            uint256 base = polyIndex * 1024; // 256*4
            assembly ("memory-safe") {
                let outPtr := out
                let cdPtr := add(packed.offset, base)

                // i = 0..255 step 8 (бо calldataload 32 bytes = 8x uint32)
                for { let i := 0 } lt(i, 256) { i := add(i, 8) } {
                    let w := calldataload(cdPtr)

                    // lane0..lane7 (uint32 big-endian)
                    mstore(add(outPtr, shl(5, i)),        and(shr(224, w), 0xffffffff))
                    mstore(add(outPtr, shl(5, add(i,1))), and(shr(192, w), 0xffffffff))
                    mstore(add(outPtr, shl(5, add(i,2))), and(shr(160, w), 0xffffffff))
                    mstore(add(outPtr, shl(5, add(i,3))), and(shr(128, w), 0xffffffff))
                    mstore(add(outPtr, shl(5, add(i,4))), and(shr(96,  w), 0xffffffff))
                    mstore(add(outPtr, shl(5, add(i,5))), and(shr(64,  w), 0xffffffff))
                    mstore(add(outPtr, shl(5, add(i,6))), and(shr(32,  w), 0xffffffff))
                    mstore(add(outPtr, shl(5, add(i,7))), and(w,            0xffffffff))

                    cdPtr := add(cdPtr, 32)
                }
            }
        }
    }

    // -------------------------
    //  compute_w from pre-A_ntt
    // -------------------------
    function computeWFromPackedANtt(bytes calldata packedANtt, uint256 seed) external returns (uint256 gasUsed) {
        // vectors in NTT-domain (для microbench достатньо псевдорандому mod Q)
        uint256[256][L] memory zNttU;
        uint256[256][K] memory t1NttU;
        uint256[256] memory cNttU;

        unchecked {
            for (uint256 j = 0; j < L; ++j) zNttU[j] = _randVec(seed + 0x1000 + j);
            for (uint256 k = 0; k < K; ++k) t1NttU[k] = _randVec(seed + 0x2000 + k);
            cNttU = _randVec(seed + 0x3000);
        }

        uint256[256] memory aNttU;   // temp poly
        uint256[256] memory accNttU; // accumulator

        uint256 g0 = gasleft();

        // w_k = sum_j A[k][j] * z_j  - c * t1_k   (all pointwise in NTT-domain)
        for (uint256 k = 0; k < K; ++k) {
            // zero acc
            for (uint256 i = 0; i < 256; ++i) accNttU[i] = 0;

            for (uint256 j = 0; j < L; ++j) {
                uint256 polyIndex = k * L + j;
                _loadPolyU32be(packedANtt, polyIndex, aNttU);

                // acc += a * z[j]
                assembly ("memory-safe") {
                    let q := 8380417
                    let accPtr := accNttU
                    let aPtr := aNttU
                    let zPtr := mload(add(zNttU, shl(5, j))) // row pointer

                    // unroll ×4, off += 0x80 over 0x2000 bytes
                    for { let off := 0 } lt(off, 0x2000) { off := add(off, 0x80) } {
                        // lane0
                        {
                            let accv := mload(add(accPtr, off))
                            let prod := mulmod(mload(add(aPtr, off)), mload(add(zPtr, off)), q)
                            accv := addmod(accv, prod, q)
                            mstore(add(accPtr, off), accv)
                        }
                        // lane1
                        {
                            let o1 := add(off, 0x20)
                            let accv := mload(add(accPtr, o1))
                            let prod := mulmod(mload(add(aPtr, o1)), mload(add(zPtr, o1)), q)
                            accv := addmod(accv, prod, q)
                            mstore(add(accPtr, o1), accv)
                        }
                        // lane2
                        {
                            let o2 := add(off, 0x40)
                            let accv := mload(add(accPtr, o2))
                            let prod := mulmod(mload(add(aPtr, o2)), mload(add(zPtr, o2)), q)
                            accv := addmod(accv, prod, q)
                            mstore(add(accPtr, o2), accv)
                        }
                        // lane3
                        {
                            let o3 := add(off, 0x60)
                            let accv := mload(add(accPtr, o3))
                            let prod := mulmod(mload(add(aPtr, o3)), mload(add(zPtr, o3)), q)
                            accv := addmod(accv, prod, q)
                            mstore(add(accPtr, o3), accv)
                        }
                    }
                }
            }

            // subtract c * t1[k]
            assembly ("memory-safe") {
                let q := 8380417
                let accPtr := accNttU
                let cPtr := cNttU
                let t1Ptr := mload(add(t1NttU, shl(5, k))) // row pointer

                for { let off := 0 } lt(off, 0x2000) { off := add(off, 0x80) } {
                    // lane0
                    {
                        let accv := mload(add(accPtr, off))
                        let term := mulmod(mload(add(cPtr, off)), mload(add(t1Ptr, off)), q)
                        accv := addmod(accv, sub(q, term), q)
                        mstore(add(accPtr, off), accv)
                    }
                    // lane1
                    {
                        let o1 := add(off, 0x20)
                        let accv := mload(add(accPtr, o1))
                        let term := mulmod(mload(add(cPtr, o1)), mload(add(t1Ptr, o1)), q)
                        accv := addmod(accv, sub(q, term), q)
                        mstore(add(accPtr, o1), accv)
                    }
                    // lane2
                    {
                        let o2 := add(off, 0x40)
                        let accv := mload(add(accPtr, o2))
                        let term := mulmod(mload(add(cPtr, o2)), mload(add(t1Ptr, o2)), q)
                        accv := addmod(accv, sub(q, term), q)
                        mstore(add(accPtr, o2), accv)
                    }
                    // lane3
                    {
                        let o3 := add(off, 0x60)
                        let accv := mload(add(accPtr, o3))
                        let term := mulmod(mload(add(cPtr, o3)), mload(add(t1Ptr, o3)), q)
                        accv := addmod(accv, sub(q, term), q)
                        mstore(add(accPtr, o3), accv)
                    }
                }
            }
        }

        gasUsed = g0 - gasleft();
    }
}

contract PreA_ComputeW_GasMicro_Test is Test {
    bytes32 internal constant RHO0 = bytes32(0);
    bytes32 internal constant RHO1 =
        hex"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f00";

    PreA_ComputeW_Runner internal runner;

    function setUp() public {
        runner = new PreA_ComputeW_Runner();
    }

    function _toNTTDomainU(int32[256] memory a) internal pure returns (uint256[256] memory r) {
        unchecked {
            int64 q = 8380417;
            for (uint256 i = 0; i < 256; ++i) {
                int64 x = int64(a[i]);
                x %= q;
                if (x < 0) x += q;
                // casting is safe: 0 <= x < q <= 8,380,417 < 2^23
                // forge-lint: disable-next-line(unsafe-typecast)
                r[i] = uint256(uint64(x));
            }
        }
    }

    function _packPolyU32be(uint256[256] memory poly, bytes memory out, uint256 outOff) internal pure {
        unchecked {
            for (uint256 i = 0; i < 256; ++i) {
                uint256 v = poly[i] & 0xffffffff;
                uint256 p = outOff + i * 4;

                // All casts are safe: v is masked to 32 bits.
                // forge-lint: disable-next-line(unsafe-typecast)
                out[p + 0] = bytes1(uint8(v >> 24));
                // forge-lint: disable-next-line(unsafe-typecast)
                out[p + 1] = bytes1(uint8(v >> 16));
                // forge-lint: disable-next-line(unsafe-typecast)
                out[p + 2] = bytes1(uint8(v >> 8));
                // forge-lint: disable-next-line(unsafe-typecast)
                out[p + 3] = bytes1(uint8(v));
            }
        }
    }

    function _buildPackedANtt(bytes32 rho) internal pure returns (bytes memory packed) {
        // K*L = 30 polys, each 1024 bytes
        packed = new bytes(30 * 1024);

        uint256 polyIndex = 0;
        for (uint256 row = 0; row < 6; ++row) {
            for (uint256 col = 0; col < 5; ++col) {
                int32[256] memory aI32 = MLDSA65_ExpandA_KeccakFIPS204.expandA_poly(rho, row, col);
                uint256[256] memory aU = _toNTTDomainU(aI32);
                uint256[256] memory aNtt = NTT_MLDSA_Real.ntt(aU);

                _packPolyU32be(aNtt, packed, polyIndex * 1024);
                polyIndex++;
            }
        }
    }

    function test_compute_w_fromPacked_A_ntt_gas_rho0() public {
        bytes memory packed = _buildPackedANtt(RHO0);
        uint256 g = runner.computeWFromPackedANtt(packed, 0xBEEF);
        emit log_named_uint("gas_compute_w_fromPacked_A_ntt(rho0)", g);
    }

    function test_compute_w_fromPacked_A_ntt_gas_rho1() public {
        bytes memory packed = _buildPackedANtt(RHO1);
        uint256 g = runner.computeWFromPackedANtt(packed, 0xBEEF);
        emit log_named_uint("gas_compute_w_fromPacked_A_ntt(rho1)", g);
    }
}
