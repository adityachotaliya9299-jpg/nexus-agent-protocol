// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ReputationOracle} from "../src/reputation/ReputationOracle.sol";

/// @notice Deployment script for Phase 2A — ReputationOracle
/// @dev Run after Phase 1A+1B (AgentRegistry must already be deployed)
///      forge script script/DeployReputationOracle.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
contract DeployReputationOracleScript is Script {
    // ============================================================
    //     FILL THESE IN AFTER PHASE 1 DEPLOYMENT
    // ============================================================

    /// @dev AgentRegistry address from Phase 1A deployment
    address constant AGENT_REGISTRY = address(0); // TODO: fill after Phase 1A deploy

    function run() external {
        require(AGENT_REGISTRY != address(0), "Set AGENT_REGISTRY address first");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Nexus Agent Protocol - Phase 2A Deployment ===");
        console.log("Deployer:         ", deployer);
        console.log("Network:          ", block.chainid);
        console.log("AgentRegistry:    ", AGENT_REGISTRY);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy ReputationOracle
        ReputationOracle oracle = new ReputationOracle(deployer, AGENT_REGISTRY);

        // Authorize oracle to write reputation back to registry
        // (requires calling registry.setReputationUpdater(address(oracle), true))
        // Done separately since registry owner must call it

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployed Contracts ===");
        console.log("ReputationOracle: ", address(oracle));
        console.log("");
        console.log("Post-deploy steps:");
        console.log("  1. Call registry.setReputationUpdater(oracle, true)");
        console.log("  2. Call oracle.setAuthorizedUpdater(marketplace, true)  [Phase 3]");
        console.log("  3. Call oracle.setAuthorizedUpdater(avs, true)          [Phase 4]");
        console.log("  4. For each existing agent: oracle.initializeAgent(agentId)");
        console.log("  5. Verify on Etherscan");
    }
}
