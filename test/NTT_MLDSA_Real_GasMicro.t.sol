// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/ntt/NTT_MLDSA_Real.sol";

contract NTT_MLDSA_Real_GasMicro_Test is Test {
    uint256 internal constant Q = 8380417;

    function _randPoly(bytes32 seed) internal pure returns (uint256[256] memory a) {
        for (uint256 i = 0; i < 256; ++i) {
            a[i] = uint256(keccak256(abi.encodePacked(seed, i))) % Q;
        }
    }

    function test_gas_ntt_single_poly() public {
        uint256[256] memory a = _randPoly(keccak256("a"));
        uint256 g0 = gasleft();
        NTT_MLDSA_Real.ntt(a);
        uint256 g1 = gasleft();
        emit log_named_uint("gas_ntt_single_poly", g0 - g1);
    }

    function test_gas_intt_single_poly() public {
        uint256[256] memory a = _randPoly(keccak256("a"));
        NTT_MLDSA_Real.ntt(a);
        uint256 g0 = gasleft();
        NTT_MLDSA_Real.intt(a);
        uint256 g1 = gasleft();
        emit log_named_uint("gas_intt_single_poly", g0 - g1);
    }
}
