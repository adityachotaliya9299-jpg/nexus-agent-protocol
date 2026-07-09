// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AgentCoordinator} from "../src/coordination/AgentCoordinator.sol";

/// @title DeployCoordinator
/// @notice Deploys AgentCoordinator — the final protocol contract.
///
/// After this deployment, run the mainnet checklist:
///   node scripts/mainnet-checklist.js
///
/// Usage (Sepolia):
   
///
/// Usage (Mainnet — when ready):
///   forge script script/DeployCoordinator.s.sol \
///     --rpc-url $MAINNET_RPC_URL \
///     --broadcast \
///     --verify \
///     --etherscan-api-key $ETHERSCAN_API_KEY \
///     -vvvv
contract DeployCoordinator is Script {
    function run() external {
        uint256 deployerKey      = vm.envUint("PRIVATE_KEY");
        address deployer         = vm.addr(deployerKey);
        address agentRegistry    = vm.envAddress("AGENT_REGISTRY_ADDR");
        address reputationOracle = vm.envAddress("REPUTATION_ORACLE_ADDR");

        console.log("==========================================");
        console.log("Deploying AgentCoordinator");
        console.log("==========================================");
        console.log("Deployer:         ", deployer);
        console.log("AgentRegistry:    ", agentRegistry);
        console.log("ReputationOracle: ", reputationOracle);
        console.log("Chain ID:         ", block.chainid);

        vm.startBroadcast(deployerKey);

        AgentCoordinator coordinator = new AgentCoordinator(
            deployer,
            agentRegistry,
            reputationOracle
        );

        vm.stopBroadcast();

        console.log("");
        console.log("==========================================");
        console.log("AgentCoordinator deployed:", address(coordinator));
        console.log("==========================================");
        console.log("Add to .env:");
        console.log("  COORDINATOR_ADDR=", address(coordinator));
        console.log("");
        console.log("NEXUS PROTOCOL COMPLETE");
        console.log("All contracts deployed. Run mainnet checklist:");
        console.log("  node scripts/mainnet-checklist.js");
        console.log("==========================================");
    }
}
