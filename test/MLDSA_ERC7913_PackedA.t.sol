// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../contracts/interfaces/IERC7913SignatureVerifier.sol";
import "../contracts/verifier/MLDSA65_ERC7913Verifier.sol";
import "../contracts/verifier/MLDSA65_ERC7913BoundCommitA.sol";

contract MLDSA_ERC7913_PackedA_Test is Test {
    MLDSA65_ERC7913Verifier internal adapter;
    MLDSA65_ERC7913BoundCommitA internal boundV; // НЕ "bound" (конфлікт із forge-std)

    // --------
    // FIXTURES (вставиш зі свого microbench)
    // --------
    bytes32 internal msgHash;

    bytes internal pk;
    bytes internal sig_ok;
    bytes internal sig_bad;

    bytes internal packedA_ntt;
    bytes32 internal commitA;

    function setUp() public {
        adapter = new MLDSA65_ERC7913Verifier();
        boundV  = new MLDSA65_ERC7913BoundCommitA();

        // -----------------------------
        // TODO: встав сюди реальні дані
        // -----------------------------
        // msgHash = 0x...;
        // pk = hex"...";
        // sig_ok = hex"...";
        // sig_bad = hex"..."; // напр. sig_ok з 1 зіпсованим байтом
        // packedA_ntt = hex"...";
        // commitA = keccak256(packedA_ntt);

        // щоб тест не “падав” поки не вставив fixtures:
        if (pk.length == 0) return;

        _setCommitA_flexible(commitA, packedA_ntt);
    }

    // -------------------------
    // Flexible setter (handles setCommitA ABI variations)
    // -------------------------

    function _setCommitA_flexible(bytes32 cA, bytes memory packedA) internal {
        // 1) setCommitA(bytes32)
        (bool ok1, ) = address(boundV).call(
            abi.encodeWithSignature("setCommitA(bytes32)", cA)
        );
        if (ok1) return;

        // 2) setCommitA(bytes32,bytes)
        (bool ok2, ) = address(boundV).call(
            abi.encodeWithSignature("setCommitA(bytes32,bytes)", cA, packedA)
        );
        if (ok2) return;

        // 3) setCommitA(bytes32,bytes32) (на випадок якщо другий аргумент — якийсь salt/rho)
        (bool ok3, ) = address(boundV).call(
            abi.encodeWithSignature("setCommitA(bytes32,bytes32)", cA, bytes32(0))
        );
        if (ok3) return;

        revert("setCommitA: no matching ABI");
    }

    // -------------------------
    // Low-level helpers
    // -------------------------

    function _callBytes4(address target, bytes memory data) internal view returns (bool ok, bytes4 out) {
        (bool success, bytes memory ret) = target.staticcall(data);
        if (!success || ret.length < 32) return (false, bytes4(0));
        out = abi.decode(ret, (bytes4));
        return (true, out);
    }

    /// @dev Adapter verifyWithPackedA має десь 2 “типові” порядки аргументів.
    ///      Ми пробуємо обидва, щоб не прив’язувати тест до твоїх локальних рішень.
    function _adapterVerifyWithPackedA(
        MLDSA65_ERC7913Verifier a,
        bytes32 h,
        bytes memory sig,
        bytes memory pub,
        bytes memory packedA
    ) internal view returns (bool matched, bytes4 outSel) {
        // Variant A: verifyWithPackedA(bytes32,bytes,bytes,bytes)
        {
            (bool okA, bytes4 selA) = _callBytes4(
                address(a),
                abi.encodeWithSignature(
                    "verifyWithPackedA(bytes32,bytes,bytes,bytes)",
                    h, sig, pub, packedA
                )
            );
            if (okA) return (true, selA);
        }

        // Variant B: verifyWithPackedA(bytes,bytes32,bytes,bytes)
        {
            (bool okB, bytes4 selB) = _callBytes4(
                address(a),
                abi.encodeWithSignature(
                    "verifyWithPackedA(bytes,bytes32,bytes,bytes)",
                    pub, h, sig, packedA
                )
            );
            if (okB) return (true, selB);
        }

        return (false, bytes4(0));
    }

    function _boundVerifyWithPackedA(
        MLDSA65_ERC7913BoundCommitA b,
        bytes32 h,
        bytes memory sig,
        bytes memory pub,
        bytes32 cA,
        bytes memory packedA
    ) internal view returns (bool matched, bool success, bytes memory ret) {
        // Variant A: verifyWithPackedA(bytes32,bytes,bytes,bytes32,bytes)
        {
            (bool okA, bytes memory rA) = address(b).staticcall(
                abi.encodeWithSignature(
                    "verifyWithPackedA(bytes32,bytes,bytes,bytes32,bytes)",
                    h, sig, pub, cA, packedA
                )
            );
            if (rA.length >= 4) return (true, okA, rA);
        }

        // Variant B: verifyWithPackedA(bytes,bytes32,bytes,bytes32,bytes)
        {
            (bool okB, bytes memory rB) = address(b).staticcall(
                abi.encodeWithSignature(
                    "verifyWithPackedA(bytes,bytes32,bytes,bytes32,bytes)",
                    pub, h, sig, cA, packedA
                )
            );
            if (rB.length >= 4) return (true, okB, rB);
        }

        return (false, false, bytes(""));
    }

    // -------------------------
    // Tests
    // -------------------------

    function test_erc7913_adapter_verifyWithPackedA_ok_and_mismatch() public view {
        if (pk.length == 0) return; // fixtures ще не вставлені

        (bool matchedOk, bytes4 okSel) = _adapterVerifyWithPackedA(adapter, msgHash, sig_ok, pk, packedA_ntt);
        require(matchedOk, "verifyWithPackedA() not found on adapter (ABI mismatch)");
        assertEq(okSel, IERC7913SignatureVerifier.verify.selector, "ok must return IERC7913 verify.selector");

        (bool matchedBad, bytes4 badSel) = _adapterVerifyWithPackedA(adapter, msgHash, sig_bad, pk, packedA_ntt);
        require(matchedBad, "verifyWithPackedA() not found on adapter (ABI mismatch)");
        assertTrue(badSel == bytes4(0) || badSel != IERC7913SignatureVerifier.verify.selector, "bad must fail");
    }

    function test_erc7913_boundCommitA_verifyWithPackedA_ok_and_commit_mismatch() public {
        if (pk.length == 0) return; // fixtures ще не вставлені

        // OK path
        {
            (bool matched, bool success, bytes memory ret) =
                _boundVerifyWithPackedA(boundV, msgHash, sig_ok, pk, commitA, packedA_ntt);

            require(matched, "verifyWithPackedA() not found on bound verifier (ABI mismatch)");
            require(success && ret.length >= 32, "expected success return");

            bytes4 sel = abi.decode(ret, (bytes4));
            assertEq(sel, IERC7913SignatureVerifier.verify.selector, "ok must return IERC7913 verify.selector");
        }

        // Commit mismatch must revert with CommitA_Mismatch()
        {
            bytes32 badCommitA = bytes32(uint256(commitA) ^ 1);

            (bool matched, bool success, bytes memory ret) =
                _boundVerifyWithPackedA(boundV, msgHash, sig_ok, pk, badCommitA, packedA_ntt);

            require(matched, "verifyWithPackedA() not found on bound verifier (ABI mismatch)");
            require(!success, "expected revert on commit mismatch");
            require(ret.length >= 4, "empty revert data");

            bytes4 errSel;
            assembly { errSel := mload(add(ret, 32)) }

            assertEq(errSel, MLDSA65_ERC7913BoundCommitA.CommitA_Mismatch.selector, "wrong revert selector");
        }
    }
}
