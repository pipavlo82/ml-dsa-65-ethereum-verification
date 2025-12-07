// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library BarrettMLDSA {
    uint256 constant Q = 8380417;

    // μ = floor(2^256 / Q)
    uint256 constant MU =
        14334930313597814316593802113514784129213392846350383673583265251583094184651;

    /**
     * Full Barrett reduction for 256-bit x.
     *
     * r = x - floor(x / q) * q
     * floor(x / q) ≈ (x * μ) >> 256
     */
    function barrettReduce(uint256 x) internal pure returns (uint256 r) {
        unchecked {
            uint256 t = mul256(x, MU);  // (x * MU) >> 256
            r = x - t * Q;

            if (r >= Q) r -= Q;
            if (r >= Q) r -= Q;
        }
    }

    /**
     * Multiply and shift-right-256: (a * b) >> 256.
     * Uses Solidity 0.8 builtins.
     */
    function mul256(uint256 a, uint256 b) internal pure returns (uint256 c) {
        unchecked {
            uint256 ah = a >> 128;
            uint256 al = a & ((1 << 128) - 1);
            uint256 bh = b >> 128;
            uint256 bl = b & ((1 << 128) - 1);

            uint256 ah_bh = ah * bh;
            uint256 al_bl = al * bl;

            uint256 ah_bl = ah * bl;
            uint256 al_bh = al * bh;

            uint256 mid = (ah_bl + al_bh);
            uint256 mid_low = mid << 128;
            uint256 mid_high = mid >> 128;

            uint256 resHigh = ah_bh + mid_high;
            uint256 resLow = mid_low + al_bl;

            if (resLow < mid_low) {
                resHigh += 1;
            }

            c = resHigh;
        }
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return barrettReduce(a * b);
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256 r) {
        unchecked {
            r = a + b;
            if (r >= Q) r -= Q;
        }
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256 r) {
        unchecked {
            r = a + Q - b;
            if (r >= Q) r -= Q;
        }
    }
}
