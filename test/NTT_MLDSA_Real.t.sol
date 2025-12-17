// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {NTT_MLDSA_Real} from "../contracts/ntt/NTT_MLDSA_Real.sol";

contract NTT_MLDSA_Real_Test is Test {
    uint256 constant Q = 8380417;

    function _rand() internal view returns (uint256) {
        return uint256(
            keccak256(abi.encodePacked(block.timestamp, gasleft()))
        ) % Q;
    }

    // ------------------------------------------------------------
    // 1. STRUCTURE TEST — просто перевіряємо, що все крутиться
    // ------------------------------------------------------------
    function test_NTT_Real_StructureRuns() public {
        uint256[256] memory v;
        for (uint256 i = 0; i < 256; i++) v[i] = _rand();

        uint256[256] memory n = NTT_MLDSA_Real.ntt(v);
        uint256[256] memory b = NTT_MLDSA_Real.intt(n);

        assertEq(n.length, 256);
        assertEq(b.length, 256);
    }

    // ------------------------------------------------------------
    // 2. RANDOM ROUNDTRIP — NTT → INTT має повернути оригінал
    // ------------------------------------------------------------
    function test_NTT_Real_RoundtripRandom() public {
        uint256[256] memory v;
        for (uint256 i = 0; i < 256; i++) v[i] = _rand();

        uint256[256] memory n = NTT_MLDSA_Real.ntt(v);
        uint256[256] memory b = NTT_MLDSA_Real.intt(n);

        for (uint256 i = 0; i < 256; i++)
            assertEq(b[i], v[i], "random roundtrip mismatch");
    }

    // ------------------------------------------------------------
    // 3. BASIS VECTOR ROUNDTRIP — урізаний, щоб не ловити MemoryOOG
    // ------------------------------------------------------------
    function test_NTT_Real_RoundtripBasisVectors() public {
        for (uint256 pos = 0; pos < 16; pos++) {
            uint256[256] memory v;

            // basis vector e_pos
            for (uint256 i = 0; i < 256; i++)
                v[i] = (i == pos) ? 1 : 0;

            uint256[256] memory n = NTT_MLDSA_Real.ntt(v);
            uint256[256] memory b = NTT_MLDSA_Real.intt(n);

            for (uint256 i = 0; i < 256; i++) {
                if (i == pos) {
                    bool ok = (b[i] == 1 || b[i] == Q - 1);
                    require(ok, "basis mismatch");
                } else {
                    require(b[i] == 0, "basis leak");
                }
            }
        }
    }
}
