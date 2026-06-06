// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AgentMemory} from "../src/memory/AgentMemory.sol";

/// @notice Deployment script for Phase 2B — AgentMemory
/// @dev Run after Phase 1A (AgentRegistry must already be deployed)
///      forge script script/DeployAgentMemory.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
contract DeployAgentMemoryScript is Script {
    /// @dev AgentRegistry address from Phase 1A deployment
    address constant AGENT_REGISTRY    = address(0); 

    /// @dev TaskMarketplace address (Phase 3) — authorize after deploy
    address constant TASK_MARKETPLACE  = address(0); 

    function run() external {
        require(AGENT_REGISTRY != address(0), "Set AGENT_REGISTRY address first");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Nexus Agent Protocol - Phase 2B Deployment ===");
        console.log("Deployer:         ", deployer);
        console.log("Network:          ", block.chainid);
        console.log("AgentRegistry:    ", AGENT_REGISTRY);

        vm.startBroadcast(deployerPrivateKey);

        AgentMemory agentMemory = new AgentMemory(deployer, AGENT_REGISTRY);

        // Authorize marketplace if already deployed
        if (TASK_MARKETPLACE != address(0)) {
            agentMemory.setAuthorizedWriter(TASK_MARKETPLACE, true);
            console.log("Authorized marketplace as writer:", TASK_MARKETPLACE);
        }

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployed Contracts ===");
        console.log("AgentMemory:      ", address(agentMemory));
        console.log("");
        console.log("Post-deploy steps:");
        console.log("  1. Verify on Etherscan");
        console.log("  2. agentMemory.setAuthorizedWriter(marketplace, true)   [Phase 3]");
        console.log("  3. agentMemory.setAuthorizedWriter(avs, true)           [Phase 4]");
        console.log("  4. For each registered agent: agentMemory.initializeAgent(id, owner)");
    }
}
