// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_Verifier_v2.sol";

/// @dev Невеликий harness, щоб дістатися до _compute_w без зміни production-контракту.
contract MatrixVecHarness is MLDSA65_Verifier_v2 {
    /// @notice w = A · z для z = 0
    function computeWZeroZ(
        bytes32 rho
    ) external pure returns (MLDSA65_PolyVec.PolyVecK memory w) {
        DecodedPublicKey memory dpk;
        dpk.rho = rho;

        DecodedSignature memory dsig;
        // dsig.z, dsig.c, dsig.h за замовчуванням нулі

        w = _compute_w(dpk, dsig);
    }

    /// @notice w = A · z для z, де лише один коефіцієнт ненульовий.
    function computeWWithUnitZ(
        bytes32 rho,
        uint8 lIndex,
        uint16 coeffIndex,
        int32 value
    ) external pure returns (MLDSA65_PolyVec.PolyVecK memory w) {
        require(lIndex < MLDSA65_PolyVec.L, "invalid lIndex");
        require(coeffIndex < MLDSA65_PolyVec.N, "invalid coeffIndex");

        DecodedPublicKey memory dpk;
        dpk.rho = rho;

        DecodedSignature memory dsig;
        dsig.z.polys[lIndex][coeffIndex] = value;

        w = _compute_w(dpk, dsig);
    }
}

contract MLDSA_MatrixVec_Test is Test {
    MatrixVecHarness internal harness;
    int32 internal constant Q = 8380417;

    function setUp() public {
        harness = new MatrixVecHarness();
    }

    /// @notice Перевірка: якщо z = 0, то w = 0 для всіх рядків та коефіцієнтів.
    function test_matrixvec_zero_z_yields_zero_w() public {
        bytes32 rho = keccak256("rho_zero_z");
        MLDSA65_PolyVec.PolyVecK memory w = harness.computeWZeroZ(rho);

        for (uint256 k = 0; k < MLDSA65_PolyVec.K; ++k) {
            for (uint256 i = 0; i < MLDSA65_PolyVec.N; ++i) {
                assertEq(
                    int256(w.polys[k][i]),
                    int256(0),
                    "w must be zero when z is zero"
                );
            }
        }
    }

    /// @notice Структурний тест лінійності: A · (2e) = 2 · (A · e) (mod q)
    /// Ім'я залишаємо старе, щоб не ламати історію: test_matrixvec_unit_basis_matches_expandA.
    function test_matrixvec_unit_basis_matches_expandA() public {
        bytes32 rho = keccak256("rho_unit_basis");

        uint8 lIndex = 0;
        uint16 coeffIndex = 0;

        // w1 = A · (1 * e)
        MLDSA65_PolyVec.PolyVecK memory w1 = harness.computeWWithUnitZ(
            rho,
            lIndex,
            coeffIndex,
            1
        );

        // w2 = A · (2 * e)
        MLDSA65_PolyVec.PolyVecK memory w2 = harness.computeWWithUnitZ(
            rho,
            lIndex,
            coeffIndex,
            2
        );

        // Перевіряємо: w2 == 2 * w1 (mod Q) для всіх коефіцієнтів.
        int64 q = int64(Q);

        for (uint256 k = 0; k < MLDSA65_PolyVec.K; ++k) {
            for (uint256 i = 0; i < MLDSA65_PolyVec.N; ++i) {
                int64 v1 = int64(w1.polys[k][i]);
                int64 v2 = int64(w2.polys[k][i]);

                int64 expected = (2 * v1) % q;
                if (expected < 0) expected += q;

                assertEq(
                    int256(v2),
                    int256(expected),
                    "matrix-vector multiply must be linear in scalar"
                );
            }
        }
    }
}
