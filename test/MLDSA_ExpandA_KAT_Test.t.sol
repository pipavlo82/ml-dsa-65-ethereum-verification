// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_Verifier_v2.sol";
import "../contracts/verifier/MLDSA65_ExpandA_Synthetic_FIPSShape.sol";

/// @notice KAT для синтетичної ExpandA: перевіряємо, що A(rho) дає
/// очікувані коефіцієнти для кількох рядків / стовпців.
contract MLDSA_ExpandA_KAT_Test is Test {
    using MLDSA65_ExpandA_Synthetic_FIPSShape for bytes32;

    function test_expandA_synth_matches_kat() public {
        // 1) Читаємо JSON з rho та еталонними коефіцієнтами
        string memory json = vm.readFile("test_vectors/expandA_synth_001.json");

        // 2) rho як bytes32
        bytes memory rhoBytes = vm.parseJsonBytes(json, ".rho");
        bytes32 rho;
        assembly {
            rho := mload(add(rhoBytes, 32))
        }

        // 3) Дістаємо еталонні коефіцієнти
        bytes memory row0Col0Bytes = vm.parseJson(json, ".row0_col0_first8");
        uint256[] memory row0Col0 = abi.decode(row0Col0Bytes, (uint256[]));

        bytes memory row1Col2Bytes = vm.parseJson(json, ".row1_col2_first8");
        uint256[] memory row1Col2 = abi.decode(row1Col2Bytes, (uint256[]));

        assertEq(row0Col0.length, 8, "row0_col0_first8 length");
        assertEq(row1Col2.length, 8, "row1_col2_first8 length");

        // 4) Викликаємо on-chain ExpandA
        MLDSA65_PolyVec.PolyVecK[5] memory A = MLDSA65_ExpandA_Synthetic_FIPSShape.expandA(rho);

        // 5) Перевіряємо перші 8 коефіцієнтів для [row=0, col=0]
        for (uint256 i = 0; i < 8; ++i) {
            uint256 got = uint256(uint32(uint256(int256(A[0].polys[0][i]))));
            assertEq(got, row0Col0[i], "mismatch in A[0][0][i]");
        }

        // 6) Перевіряємо перші 8 коефіцієнтів для [row=1, col=2]
        for (uint256 i = 0; i < 8; ++i) {
            uint256 got = uint256(uint32(uint256(int256(A[1].polys[2][i]))));
            assertEq(got, row1Col2[i], "mismatch in A[1][2][i]");
        }
    }
}
