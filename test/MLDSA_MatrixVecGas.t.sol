// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_Verifier_v2.sol";

/// @notice Gas profiling for w = A*z - c*t1 using the current synthetic pipeline.
contract MLDSA_MatrixVecGas_Test is Test {
    MLDSA65_Verifier_v2_Harness internal verifier;

    function setUp() public {
        verifier = new MLDSA65_Verifier_v2_Harness();
    }

    /// @notice Measure gas for w = A*z with c = 0 (no challenge term).
    function test_matrixvec_w_gas_no_challenge() public {
        (
            MLDSA65_Verifier_v2.DecodedPublicKey memory dpk,
            MLDSA65_Verifier_v2.DecodedSignature memory dsig
        ) = verifier.buildSyntheticDecodedNoChallenge();

        uint256 gasUsed = verifier.measureComputeW(dpk, dsig);

        emit log_named_uint(
            "w = A*z (no challenge) gas",
            gasUsed
        );
    }

    /// @notice Measure gas for w = A*z - c*t1 with non-zero c (full synthetic path).
    function test_matrixvec_w_gas_with_challenge() public {
        (
            MLDSA65_Verifier_v2.DecodedPublicKey memory dpk,
            MLDSA65_Verifier_v2.DecodedSignature memory dsig
        ) = verifier.buildSyntheticDecodedWithChallenge();

        uint256 gasUsed = verifier.measureComputeW(dpk, dsig);

        emit log_named_uint(
            "w = A*z - c*t1 (with challenge) gas",
            gasUsed
        );
    }
}

/// @notice Harness to expose _compute_w and to build synthetic DecodedPublicKey / DecodedSignature.
contract MLDSA65_Verifier_v2_Harness is MLDSA65_Verifier_v2 {
    /// @notice Build a deterministic synthetic DecodedPublicKey + DecodedSignature with c = 0.
    function buildSyntheticDecodedNoChallenge()
        public
        pure
        returns (DecodedPublicKey memory dpk, DecodedSignature memory dsig)
    {
        // Synthetic rho seed
        dpk.rho = bytes32(uint256(0xDEADBEEF));
        // c = 0 -> no challenge term
        dsig.c = bytes32(0);

        // Fill t1 polys with a simple pattern depending on k and i:
        // t1[k][i] = i + 31 * k
        for (uint256 k = 0; k < MLDSA65_PolyVec.K; ++k) {
            for (uint256 i = 0; i < MLDSA65_PolyVec.N; ++i) {
                dpk.t1.polys[k][i] = int32(int256(i + 31 * k));
            }
        }

        // Fill z polys with another small pattern:
        // z[j][i] = i + 17 * j
        for (uint256 j = 0; j < MLDSA65_PolyVec.L; ++j) {
            for (uint256 i = 0; i < MLDSA65_PolyVec.N; ++i) {
                dsig.z.polys[j][i] = int32(int256(i + 17 * j));
            }
        }

        // dsig.h remains all zeros (HintVecL default), not used in this pipeline.
        return (dpk, dsig);
    }

    /// @notice Build a deterministic synthetic DecodedPublicKey + DecodedSignature with c != 0.
    function buildSyntheticDecodedWithChallenge()
        public
        pure
        returns (DecodedPublicKey memory dpk, DecodedSignature memory dsig)
    {
        // Synthetic rho / c seeds
        dpk.rho = bytes32(uint256(0xDEADBEEF));
        dsig.c = bytes32(uint256(0x12345678));

        // Fill t1 polys with a simple pattern depending on k and i:
        // t1[k][i] = i + 31 * k
        for (uint256 k = 0; k < MLDSA65_PolyVec.K; ++k) {
            for (uint256 i = 0; i < MLDSA65_PolyVec.N; ++i) {
                dpk.t1.polys[k][i] = int32(int256(i + 31 * k));
            }
        }

        // Fill z polys with another small pattern:
        // z[j][i] = i + 17 * j
        for (uint256 j = 0; j < MLDSA65_PolyVec.L; ++j) {
            for (uint256 i = 0; i < MLDSA65_PolyVec.N; ++i) {
                dsig.z.polys[j][i] = int32(int256(i + 17 * j));
            }
        }

        // dsig.h remains all zeros (HintVecL default), not used in this pipeline.
        return (dpk, dsig);
    }

    /// @notice Measure gas used by a single _compute_w call.
    function measureComputeW(
        DecodedPublicKey memory dpk,
        DecodedSignature memory dsig
    ) public view returns (uint256 gasUsed) {
        uint256 gasBefore = gasleft();
        MLDSA65_PolyVec.PolyVecK memory w = _compute_w(dpk, dsig);
        // silence unused-variable warning
        w;
        unchecked {
            gasUsed = gasBefore - gasleft();
        }
    }
}
