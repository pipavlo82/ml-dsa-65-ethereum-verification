// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ВАЖЛИВО: ми НЕ змінюємо ZKNox-файли, лише обгортаємо їх API.
import "./ZKNox_KeccakPRNG.sol";

/// @title MLDSA65_KeccakXOF
/// @notice Тонкий ML-DSA-орієнтований шар над ZKNox Keccak PRNG.
/// @dev Ідея: ми використовуємо KeccakPRNG як XOF-джерело для ExpandA/challenge,
///      але сам Keccak/PRNG лишається "канонічним" з ETHDILITHIUM.
library MLDSA65_KeccakXOF {
    /// @notice Стрім XOF для ML-DSA-65 (побудований на KeccakPRNG).
    struct Stream {
        KeccakPRNG prng;
    }

    /// @notice Базова ініціалізація XOF-стріму з довільним контекстом.
    /// @dev Використовуємо keccak-CTR PRNG ZKNox як бекенд.
    function initRaw(bytes memory ctx) internal pure returns (Stream memory s) {
        s.prng = initPRNG(ctx);
    }

    /// @notice Стрім для ExpandA: seed := "MLDSA65-ExpandA" || rho || row || col.
    function initExpandA(bytes32 rho, uint16 row, uint16 col) internal pure returns (Stream memory s) {
        bytes memory seed = abi.encodePacked("MLDSA65-ExpandA", rho, row, col);
        s.prng = initPRNG(seed);
    }

    /// @notice Стрім для challenge / загального XOF: seed := "MLDSA65-XOF" || rho || nonce.
    function initXOF(bytes32 rho, uint64 nonce) internal pure returns (Stream memory s) {
        bytes memory seed = abi.encodePacked("MLDSA65-XOF", rho, nonce);
        s.prng = initPRNG(seed);
    }

    /// @notice Внутрішня обгортка над глобальною nextByte(KeccakPRNG).
    function xofNextByte(Stream memory s) internal pure returns (uint8 b) {
        // Викликаємо глобальну функцію з ZKNox_KeccakPRNG.sol
        b = nextByte(s.prng);
    }

    /// @notice Зняти наступне 16-бітне слово (little-endian).
    function nextU16(Stream memory s) internal pure returns (uint16 v) {
        uint8 b0 = xofNextByte(s);
        uint8 b1 = xofNextByte(s);
        v = uint16(b0) | (uint16(b1) << 8);
    }

    /// @notice Зняти наступне 32-бітне слово (little-endian).
    function nextU32(Stream memory s) internal pure returns (uint32 v) {
        uint8 b0 = xofNextByte(s);
        uint8 b1 = xofNextByte(s);
        uint8 b2 = xofNextByte(s);
        uint8 b3 = xofNextByte(s);
        v = uint32(b0) | (uint32(b1) << 8) | (uint32(b2) << 16) | (uint32(b3) << 24);
    }

    /// @notice Витиснути кілька байт у буфер.
    function squeezeBytes(Stream memory s, uint256 len) internal pure returns (bytes memory out) {
        out = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            out[i] = bytes1(xofNextByte(s));
        }
    }
}
