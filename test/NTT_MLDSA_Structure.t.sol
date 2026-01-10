// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {NTT_MLDSA_Core}  from "../contracts/ntt/NTT_MLDSA_Core.sol";
import {NTT_MLDSA_Zetas} from "../contracts/ntt/NTT_MLDSA_Zetas.sol";

/// @title NTT structure & roundtrip tests for ML-DSA-65
contract NTT_MLDSA_Structure_Test is Test {
    uint256 internal constant Q = 8380417;

    /// -----------------------------------------------------------------------
    /// sanity-тест: NTT та INTT не падають і тримають значення в межах поля
    /// -----------------------------------------------------------------------
    function test_NTT_StructureRuns() public {
        uint256[256] memory a;
        for (uint256 i = 0; i < 256; i++) {
            a[i] = i % Q;
        }

        uint256[256] memory out1 = NTT_MLDSA_Core.ntt(a);
        uint256[256] memory out2 = NTT_MLDSA_Core.intt(out1);

        // Значення повинні завжди бути < Q
        for (uint256 i = 0; i < 256; i++) {
            assertLt(out1[i], Q, "NTT output out of field");
            assertLt(out2[i], Q, "INTT output out of field");
        }
    }

    /// -----------------------------------------------------------------------
    /// Повний roundtrip: INTT(NTT(a)) == a для випадкового полінома
    /// -----------------------------------------------------------------------
    function test_NTT_RoundtripRandom() public {
        uint256[256] memory a;
        uint256[256] memory b;
        uint256[256] memory c;

        // Детермінований «random» поліном
        for (uint256 i = 0; i < 256; i++) {
            a[i] = uint256(keccak256(abi.encode(i, "ntt_random"))) % Q;
        }

        b = NTT_MLDSA_Core.ntt(a);
        c = NTT_MLDSA_Core.intt(b);

        for (uint256 i = 0; i < 256; i++) {
            assertEq(c[i], a[i], "NTT roundtrip mismatch");
        }
    }

    /// -----------------------------------------------------------------------
    /// Roundtrip для базисних векторів e_k
    /// e_k = (0,0,...,1 на позиції k,...0)
    /// Це ловить проблеми з індексами, bit-reversal, butterfly-логікою.
    /// -----------------------------------------------------------------------
    function test_NTT_RoundtripBasisVectors() public {
        for (uint256 k = 0; k < 8; k++) {         // Перевіримо перші 8 базисів
            uint256[256] memory e;
            uint256[256] memory back;

            e[k] = 1;                             // e_k

            back = NTT_MLDSA_Core.intt(
                NTT_MLDSA_Core.ntt(e)
            );

            for (uint256 i = 0; i < 256; i++) {
                uint256 expected = (i == k) ? 1 : 0;
                assertEq(back[i], expected, "NTT basis roundtrip mismatch");
            }
        }
    }
}
