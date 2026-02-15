// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "../contracts/verifier/MLDSA65_Verifier_v2.sol";

/// @notice Harness to expose public key decode for KAT tests.
contract MLDSA_T1_KAT_Harness is MLDSA65_Verifier_v2 {
    function exposedDecodePublicKey(bytes memory raw)
        external
        pure
        returns (DecodedPublicKey memory)
    {
        PublicKey memory pk = PublicKey({raw: raw});
        return _decodePublicKey(pk);
    }
}

/// @notice KAT tests for ML-DSA-65 t1 decode (6×256 coefficients).
/// @dev Працює з JSON-вектором, згенерованим скриптом vectors/gen_mldsa65_t1_kat.py.
contract MLDSA_T1_KAT_Test is Test {
    using stdJson for string;

    MLDSA_T1_KAT_Harness internal harness;

    function setUp() public {
        harness = new MLDSA_T1_KAT_Harness();
    }

    /// @dev Повний KAT для t1: звіряємо всі 6×256 коефіцієнтів з JSON.
    function test_t1_full_kat_001() public {
        // 1. Зчитуємо JSON
        string memory json = vm.readFile("vectors/mldsa65_t1_kat_001.json");

        // 2. Дістаємо pubkey (hex-encoded 1952 байти: t1_packed || rho)
        bytes memory pkRaw = vm.parseBytes(
            json.readString(".pubkey")
        );
        assertEq(pkRaw.length, 1920 + 32, "pk length mismatch");

        // 3. Декодуємо через MLDSA65_Verifier_v2
        MLDSA65_Verifier_v2.DecodedPublicKey memory dpk =
            harness.exposedDecodePublicKey(pkRaw);

        uint256 K = 6;
        uint256 N = 256;

        // 4. Обходимо всі 6×256 коефіцієнтів і звіряємо з референсом із JSON.
        for (uint256 k = 0; k < K; ++k) {
            for (uint256 i = 0; i < N; ++i) {
                // шлях типу: .t1[0][0], .t1[0][1], ..., .t1[5][255]
                string memory key = string(
                    abi.encodePacked(
                        ".t1[", vm.toString(k), "][", vm.toString(i), "]"
                    )
                );

                int256 expectedCoeff = json.readInt(key);

                assertEq(
                    int256(dpk.t1.polys[k][i]),
                    expectedCoeff,
                    "t1 coeff mismatch"
                );
            }
        }
    }
}
