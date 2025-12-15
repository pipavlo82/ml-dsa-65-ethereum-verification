// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MLDSA65_Verifier_v2} from "../contracts/verifier/MLDSA65_Verifier_v2.sol";

contract VerifyWithPackedA_GasMicro_Test is Test {
    uint256 internal constant PK_LEN = 1952;        // 1920 t1 + 32 rho
    uint256 internal constant T1_LEN = 1920;
    uint256 internal constant PACKED_A_NTT_LEN = 30 * 1024; // 30720 bytes

    MLDSA65_Verifier_v2 internal v;

    function setUp() public {
        v = new MLDSA65_Verifier_v2();
    }

    function _mkPubkey(bytes32 rho) internal pure returns (bytes memory pk) {
        pk = new bytes(PK_LEN); // zero t1 by default
        // write rho at offset 1920
        assembly ("memory-safe") {
            mstore(add(add(pk, 0x20), T1_LEN), rho)
        }
    }

    function _mkSigC(bytes32 c) internal pure returns (bytes memory sig) {
        sig = new bytes(32);
        assembly ("memory-safe") {
            mstore(add(sig, 0x20), c)
        }
    }

    function _mkPackedA() internal pure returns (bytes memory packedA) {
        packedA = new bytes(PACKED_A_NTT_LEN); // all zeros is fine for gas microbench
    }

    function test_gas_verifyWithPackedA_ok() public {
        bytes32 rho = bytes32(uint256(2));
        bytes32 c = bytes32(uint256(1));

        bytes memory pk = _mkPubkey(rho);
        bytes memory sig = _mkSigC(c);
        bytes memory packedA = _mkPackedA();

        uint256 g0 = gasleft();
        uint256 ok = v.verifyWithPackedA(pk, sig, c, packedA);
        uint256 used = g0 - gasleft();

        emit log_named_uint("gas_verifyWithPackedA(ok=1)", used);
        assertEq(ok, 1);
    }

    function test_gas_verifyWithPackedA_mismatch() public {
        bytes32 rho = bytes32(uint256(2));
        bytes32 c = bytes32(uint256(1));

        bytes memory pk = _mkPubkey(rho);
        bytes memory sig = _mkSigC(c);
        bytes memory packedA = _mkPackedA();

        bytes32 wrongDigest = bytes32(uint256(3));

        uint256 g0 = gasleft();
        uint256 ok = v.verifyWithPackedA(pk, sig, wrongDigest, packedA);
        uint256 used = g0 - gasleft();

        emit log_named_uint("gas_verifyWithPackedA(ok=0 mismatch)", used);
        assertEq(ok, 0);
    }
}

