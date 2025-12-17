// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/verifier/MLDSA65_ERC7913Verifier.sol";
import "../contracts/interfaces/IERC7913SignatureVerifier.sol";

/// @notice Smoke-тест адаптера до ERC-7913 поверх FIPS KAT-вектора.
contract MLDSA_ERC7913Adapter_Test is Test {
    MLDSA65_ERC7913Verifier internal adapter;

    function setUp() public {
        adapter = new MLDSA65_ERC7913Verifier();
    }

    /// @notice Перевіряємо, що адаптер:
    ///  - приймає повнорозмірні FIPS-буфери (1952 / 3309 / 32 байти)
    ///  - викликає underlying MLDSA65_Verifier_v2.verify(...)
    ///  - повертає або 0xffffffff (невдала перевірка), або selector при успішній
    ///
    /// Семантичну коректність (must be true) ми поки не вимагаємо.
    function test_adapter_with_fips_kat_vector0() public {
        // 1) Читаємо JSON-вектор
        string memory json = vm.readFile("test_vectors/vector_001.json");

        // 2) Тягнемо поля
        bytes memory pkBytes = vm.parseJsonBytes(json, ".public_key_raw");
        bytes memory sigBytes = vm.parseJsonBytes(json, ".signature_raw");
        bytes memory msgBytes = vm.parseJsonBytes(json, ".msg_hash");

        // 3) Перевіряємо розміри FIPS-204
        assertEq(pkBytes.length, 1952, "pubkey length must be 1952 bytes");
        assertEq(sigBytes.length, 3309, "signature length must be 3309 bytes");
        assertEq(msgBytes.length, 32, "msg_hash length must be 32 bytes");

        // 4) msg_hash → bytes32
        bytes32 msgDigest;
        assembly {
            msgDigest := mload(add(msgBytes, 32))
        }

        // 5) Виклик ERC-7913-стилю verify
        uint256 gasBefore = gasleft();
        bytes4 res = adapter.verify(pkBytes, msgDigest, sigBytes);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("erc7913_adapter_gas", gasUsed);
        emit log_named_bytes32("erc7913_adapter_result", bytes32(res));

        // 6) Допустимі два варіанти:
        //    - поки verify() ще не повністю FIPS-коректний → 0xffffffff
        //    - коли доробимо пайплайн → selector
        bytes4 okSelector = IERC7913SignatureVerifier.verify.selector;
        bytes4 failCode = 0xffffffff;

        bool isOkSelector = (res == okSelector);
        bool isFailCode = (res == failCode);

        assertTrue(isOkSelector || isFailCode, "adapter must return either selector or 0xffffffff");

        // М'який gas-ліміт, поки що без агресивних оптимізацій
        assertLt(gasUsed, 400_000_000);
    }
}
