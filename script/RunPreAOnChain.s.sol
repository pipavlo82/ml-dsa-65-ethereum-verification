// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console2.sol";
import "forge-std/Test.sol";

// We reuse the exact builder from the test to avoid wiring drift.
import "test/PreA_ComputeW_GasMicro.t.sol";

contract RunPreAOnChain is PreA_ComputeW_GasMicro_Test {
    function run() external {
        // Broadcast settings come from forge script flags (--private-key / --broadcast).
        vm.startBroadcast();

        PreA_ComputeW_Runner runner = new PreA_ComputeW_Runner();

        // Same flow as the gas micro tests: build packedA_ntt deterministically from RHO{0,1}
        bytes memory packed0 = _buildPackedANtt(RHO0);
        uint256 g0 = runner.computeWFromPackedANtt(packed0, 0);
        console2.log("gas_compute_w_fromPacked_A_ntt(rho0)", g0);

        bytes memory packed1 = _buildPackedANtt(RHO1);
        uint256 g1 = runner.computeWFromPackedANtt(packed1, 0);
        console2.log("gas_compute_w_fromPacked_A_ntt(rho1)", g1);

        vm.stopBroadcast();
    }
}
