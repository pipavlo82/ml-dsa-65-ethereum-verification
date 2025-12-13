// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice FIPS-style challenge polynomial for ML-DSA-65.
/// @dev Дає поліном c(x) з коефіцієнтами в {-1, 0, 1} та рівно TAU ненульових.
library MLDSA65_Challenge {
    uint256 internal constant N = 256;
    uint256 internal constant TAU = 60; // кількість ненульових коефіцієнтів

    /// @notice Базовий FIPS-подібний челендж як поліном int32[256].
    /// @dev Детермінований по seed. Інваріанти:
    ///  - рівно 60 ненульових коефіцієнтів;
    ///  - кожен ненульовий ∈ {+1, -1}.
    function poly_challenge(bytes32 seed) internal pure returns (int32[256] memory c) {
        uint256 placed = 0;
        uint256 nonce = 0;

        // Генеруємо блоки псевдовипадкових байтів через keccak(seed || nonce)
        // і вибираємо з них пари (pos, sign), доки не розставимо всі 60.
        while (placed < TAU) {
            bytes32 blockHash = keccak256(abi.encodePacked(seed, nonce));
            unchecked {
                ++nonce;
            }

            // Використовуємо байти попарно: [posByte, signByte]
            for (uint256 i = 0; i + 1 < 32 && placed < TAU; i += 2) {
                uint8 posByte = uint8(blockHash[i]);
                uint8 signByte = uint8(blockHash[i + 1]);

                // Позиція 0..255
                uint256 pos = uint256(posByte); // & 0xFF не потрібен, і так 0..255

                // Пропускаємо, якщо вже щось стоїть
                if (c[pos] != 0) {
                    continue;
                }

                // Знак: старший біт signByte
                int32 s = (signByte & 0x80) == 0 ? int32(1) : int32(-1);
                c[pos] = s;

                unchecked {
                    ++placed;
                }
            }
        }
    }

    /// @notice Старий інтерфейс для тестів: int8[256] з тими ж коефіцієнтами.
    /// @dev Повністю побудований поверх poly_challenge().
    function deriveChallenge(bytes32 seed) internal pure returns (int8[256] memory out) {
        int32[256] memory tmp = poly_challenge(seed);
        for (uint256 i = 0; i < N; ++i) {
            // safe cast: значення гарантовано в {-1, 0, 1}
            out[i] = int8(tmp[i]);
        }
    }
}
