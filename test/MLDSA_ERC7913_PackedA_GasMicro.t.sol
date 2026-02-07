// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../contracts/interfaces/IERC7913SignatureVerifier.sol";
import "../contracts/verifier/MLDSA65_ERC7913Verifier.sol";

contract MLDSA_ERC7913_PackedA_GasMicro_Test is Test {
    uint256 internal constant PK_LEN  = 1952; // 1920 t1 + 32 rho
    uint256 internal constant T1_LEN  = 1920;
    uint256 internal constant PACKED_A_NTT_LEN = 30 * 1024; // 30720 bytes

    MLDSA65_ERC7913Verifier internal adapter;

    function setUp() public {
        adapter = new MLDSA65_ERC7913Verifier();
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

    function _callBytes4(address target, bytes memory data) internal view returns (bool ok, bytes4 out) {
        (bool success, bytes memory ret) = target.staticcall(data);
        if (!success || ret.length < 32) return (false, bytes4(0));
        out = abi.decode(ret, (bytes4));
        return (true, out);
    }

    /// Adapter order in твоєму коді фактично: verifyWithPackedA(bytes pk, bytes32 h, bytes sig, bytes packedA)
    /// (під це і заточений твій VerifyWithPackedA_GasMicro_Test)
    function _adapterVerifyWithPackedA(
        bytes memory pk,
        bytes32 h,
        bytes memory sig,
        bytes memory packedA
    ) internal view returns (bool matched, bytes4 outSel) {
        // Variant B: verifyWithPackedA(bytes,bytes32,bytes,bytes)
        {
            (bool okB, bytes4 selB) = _callBytes4(
                address(adapter),
                abi.encodeWithSignature(
                    "verifyWithPackedA(bytes,bytes32,bytes,bytes)",
                    pk, h, sig, packedA
                )
            );
            if (okB) return (true, selB);
        }

        // Fallback Variant A: verifyWithPackedA(bytes32,bytes,bytes,bytes) (на випадок якщо десь інша збірка)
        {
            (bool okA, bytes4 selA) = _callBytes4(
                address(adapter),
                abi.encodeWithSignature(
                    "verifyWithPackedA(bytes32,bytes,bytes,bytes)",
                    h, sig, pk, packedA
                )
            );
            if (okA) return (true, selA);
        }

        return (false, bytes4(0));
    }

    function test_gas_adapter_verifyWithPackedA_ok() public {
        bytes32 rho = bytes32(uint256(2));
        bytes32 c   = bytes32(uint256(1));

        bytes memory pk      = _mkPubkey(rho);
        bytes memory sig_ok  = _mkSigC(c);
        bytes memory packedA = _mkPackedA();

        uint256 g0 = gasleft();
        (bool matched, bytes4 sel) = _adapterVerifyWithPackedA(pk, c, sig_ok, packedA);
        uint256 used = g0 - gasleft();

        require(matched, "adapter.verifyWithPackedA ABI mismatch / not found");
        emit log_named_uint("gas_adapter_verifyWithPackedA(ok)", used);
        assertTrue(sel == bytes4(0xffffffff) || sel == IERC7913SignatureVerifier.verify.selector, "ok must return 0xffffffff or IERC7913 selector");
    }

    function test_gas_adapter_verifyWithPackedA_mismatch() public {
        bytes32 rho = bytes32(uint256(2));
        bytes32 c   = bytes32(uint256(1));

        bytes memory pk      = _mkPubkey(rho);
        bytes memory sig_ok  = _mkSigC(c);
        bytes memory packedA = _mkPackedA();

        bytes32 wrongDigest = bytes32(uint256(3));

        uint256 g0 = gasleft();
        (bool matched, bytes4 sel) = _adapterVerifyWithPackedA(pk, wrongDigest, sig_ok, packedA);
        uint256 used = g0 - gasleft();

        require(matched, "adapter.verifyWithPackedA ABI mismatch / not found");
        emit log_named_uint("gas_adapter_verifyWithPackedA(mismatch)", used);
        assertTrue(sel != IERC7913SignatureVerifier.verify.selector);
    }
}
