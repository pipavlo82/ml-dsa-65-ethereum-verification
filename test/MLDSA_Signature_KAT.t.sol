// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "../contracts/verifier/MLDSA65_Verifier_v2.sol";

/// @notice Harness для декоду сигнатури в KAT-тестах.
contract MLDSA_Signature_KAT_Harness is MLDSA65_Verifier_v2 {
    function exposedDecodeSignature(bytes memory raw) external pure returns (DecodedSignature memory) {
        Signature memory sig = Signature({raw: raw});
        return _decodeSignature(sig);
    }
}

/// @notice KAT-тест для synthetic ML-DSA-65 сигнатури (c + перші 4 coeffs z[0]).
contract MLDSA_Signature_KAT_Test is Test {
    using stdJson for string;

    MLDSA_Signature_KAT_Harness internal harness;

    function setUp() public {
        harness = new MLDSA_Signature_KAT_Harness();
    }

    function test_sig_full_kat_001() public {
        // 1. Читаємо JSON з vectors/mldsa65_sig_kat_001.json
        string memory json = vm.readFile("vectors/mldsa65_sig_kat_001.json");

        // 2. sig: hex-encoded 0x...
        string memory sigHex = json.readString(".sig");
        bytes memory sigRaw = vm.parseBytes(sigHex);

        // 3. c: hex-encoded 32 байти
        string memory cHex = json.readString(".c");
        bytes memory cBytes = vm.parseBytes(cHex);
        assertEq(cBytes.length, 32, "c length must be 32 bytes");

        bytes32 expectedC;
        assembly {
            expectedC := mload(add(cBytes, 32))
        }

        // 4. Декодуємо сигнатуру через контракт
        MLDSA65_Verifier_v2.DecodedSignature memory dsig = harness.exposedDecodeSignature(sigRaw);

        // 5. Перевіряємо c (останнi 32 байти)
        assertEq(dsig.c, expectedC, "c mismatch");

        // 6. Перевіряємо перші 4 коефіцієнти z[0][0..3]
        for (uint256 i = 0; i < 4; ++i) {
            string memory path = string.concat(".z[0][", vm.toString(i), "]");
            int256 expectedCoeff = json.readInt(path);

            assertEq(int256(dsig.z.polys[0][i]), expectedCoeff, string.concat("z[0][", vm.toString(i), "] mismatch"));
        }
    }
}
