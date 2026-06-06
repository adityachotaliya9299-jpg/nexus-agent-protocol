// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ZKVerifier} from "../src/zk/ZKVerifier.sol";

/// @notice Deployment script for Phase 4 — ZKVerifier + AVS
/// @dev forge script script/DeployZKVerifier.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
contract DeployZKVerifierScript is Script {
    address constant AGENT_REGISTRY    = address(0); // TODO: Phase 1A
    address constant REPUTATION_ORACLE = address(0); // TODO: Phase 2A
    uint256 constant QUORUM_THRESHOLD  = 6700;       // 67% of AVS operators

    function run() external {
        require(AGENT_REGISTRY != address(0),    "Set AGENT_REGISTRY");
        require(REPUTATION_ORACLE != address(0), "Set REPUTATION_ORACLE");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Nexus Agent Protocol - Phase 4 Deployment ===");
        console.log("Deployer:          ", deployer);
        console.log("Network:           ", block.chainid);
        console.log("AgentRegistry:     ", AGENT_REGISTRY);
        console.log("ReputationOracle:  ", REPUTATION_ORACLE);
        console.log("Quorum:            ", QUORUM_THRESHOLD, "bps");

        vm.startBroadcast(deployerPrivateKey);

        ZKVerifier zkVerifier = new ZKVerifier(
            deployer,
            AGENT_REGISTRY,
            REPUTATION_ORACLE,
            QUORUM_THRESHOLD
        );

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployed Contracts ===");
        console.log("ZKVerifier:        ", address(zkVerifier));
        console.log("");
        console.log("Post-deploy steps:");
        console.log("  1. oracle.setAuthorizedUpdater(zkVerifier, true)");
        console.log("  2. Register verification keys for each proof type");
        console.log("  3. Register AVS operators");
        console.log("  4. Verify on Etherscan");
    }
}
