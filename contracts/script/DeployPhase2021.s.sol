// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ContextualReputation} from "../src/reputation/ContextualReputation.sol";
import {AgentDiscovery} from "../src/discovery/AgentDiscovery.sol";

/// @title DeployPhase2021
/// @notice Deploys ContextualReputation + AgentDiscovery and wires them together.
///
/// Usage:
///   forge script script/DeployPhase2021.s.sol \
///     --rpc-url $SEPOLIA_RPC_URL \
///     --broadcast \
///     --verify \
///     --etherscan-api-key $ETHERSCAN_API_KEY \
///     -vvvv
///
/// Environment:
///   PRIVATE_KEY            - deployer
///   AGENT_REGISTRY_ADDR    - deployed AgentRegistry
///   REPUTATION_ORACLE_ADDR - deployed ReputationOracle
///   AGENT_STAKING_ADDR     - deployed AgentStaking
contract DeployPhase2021 is Script {
    function run() external {
        uint256 deployerKey      = vm.envUint("PRIVATE_KEY");
        address deployer         = vm.addr(deployerKey);
        address agentRegistry    = vm.envAddress("AGENT_REGISTRY_ADDR");
        address reputationOracle = vm.envAddress("REPUTATION_ORACLE_ADDR");
        address agentStaking     = vm.envAddress("AGENT_STAKING_ADDR");

        console.log("==========================================");
        console.log("Deploying : Contextual Reputation + Discovery");
        console.log("==========================================");
        console.log("Deployer:         ", deployer);
        console.log("AgentRegistry:    ", agentRegistry);
        console.log("ReputationOracle: ", reputationOracle);
        console.log("AgentStaking:     ", agentStaking);

        vm.startBroadcast(deployerKey);

        // 1. Deploy ContextualReputation
        ContextualReputation contextualRep = new ContextualReputation(
            deployer,
            agentRegistry
        );
        console.log("ContextualReputation deployed:", address(contextualRep));

        // 2. Deploy AgentDiscovery
        AgentDiscovery discovery = new AgentDiscovery(
            deployer,
            agentRegistry,
            reputationOracle,
            address(contextualRep),
            agentStaking
        );
        console.log("AgentDiscovery deployed:", address(discovery));

        // 3. Authorize TaskMarketplace to update contextual rep
        address taskMarketplace = vm.envOr("TASK_MARKETPLACE_ADDR", deployer);
        contextualRep.setAuthorized(taskMarketplace, true);
        console.log("  marketplace authorized for contextual rep updates [OK]");

        // 4. Authorize deployer to index agents (for testing)
        discovery.setAuthorized(deployer, true);
        console.log("  deployer authorized to index agents [OK]");

        // 5. Index Agent #1 (already registered on Sepolia)
        try discovery.indexAgent(1) {
            console.log("  agent #1 indexed [OK]");
        } catch {
            console.log("  agent #1 not registered yet — index manually later");
        }

        vm.stopBroadcast();

        console.log("");
        console.log("==========================================");
        console.log("PHASE 20+21 DEPLOYED");
        console.log("==========================================");
        console.log("ContextualReputation: ", address(contextualRep));
        console.log("AgentDiscovery:       ", address(discovery));
        console.log("");
        console.log("Add to .env:");
        console.log("  CONTEXTUAL_REP_ADDR=", address(contextualRep));
        console.log("  DISCOVERY_ADDR=",      address(discovery));
        console.log("");
        console.log("Try discovery:");
        console.log("  cast call", address(discovery), "'totalIndexed()' --rpc-url $SEPOLIA_RPC_URL");
        console.log("  cast call", address(discovery), "'getLeaderboard(uint256,uint256)' 255 10 --rpc-url $SEPOLIA_RPC_URL");
        console.log("==========================================");
    }
}
