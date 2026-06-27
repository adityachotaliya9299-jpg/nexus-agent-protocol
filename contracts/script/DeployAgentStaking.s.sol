// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AgentStaking} from "../src/staking/AgentStaking.sol";

/// @title DeployAgentStaking
/// @notice Deploys AgentStaking and authorizes marketplace + arbitrator.
/// @author Aditya Chotaliya [adityachotaliya.xyz]
///
/// Usage:
///   forge script script/DeployAgentStaking.s.sol \
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
///   TASK_MARKETPLACE_ADDR  - deployed TaskMarketplace
///   ARBITRATOR_ADDRESS     - arbitrator (defaults to deployer)
contract DeployAgentStaking is Script {
    function run() external {
        uint256 deployerKey      = vm.envUint("PRIVATE_KEY");
        address deployer         = vm.addr(deployerKey);
        address agentRegistry    = vm.envAddress("AGENT_REGISTRY_ADDR");
        address reputationOracle = vm.envAddress("REPUTATION_ORACLE_ADDR");
        address taskMarketplace  = vm.envAddress("TASK_MARKETPLACE_ADDR");
        address arbitrator       = vm.envOr("ARBITRATOR_ADDRESS", deployer);

        console.log("==========================================");
        console.log("Deploying AgentStaking");
        console.log("==========================================");
        console.log("Deployer:         ", deployer);
        console.log("AgentRegistry:    ", agentRegistry);
        console.log("ReputationOracle: ", reputationOracle);
        console.log("TaskMarketplace:  ", taskMarketplace);
        console.log("Arbitrator:       ", arbitrator);
        console.log("Treasury:         ", deployer);

        vm.startBroadcast(deployerKey);

        AgentStaking staking = new AgentStaking(
            deployer,
            agentRegistry,
            reputationOracle,
            deployer // treasury = deployer for now, update to multisig after Phase 13
        );

        staking.setAuthorized(taskMarketplace, true);
        staking.setAuthorized(arbitrator, true);

        vm.stopBroadcast();

        console.log("");
        console.log("==========================================");
        console.log("AgentStaking deployed:", address(staking));
        console.log("==========================================");
        console.log("  Marketplace authorized: ", taskMarketplace);
        console.log("  Arbitrator authorized:  ", arbitrator);
        console.log("");
        console.log("Add to .env:");
        console.log("  AGENT_STAKING_ADDR=", address(staking));
        console.log("==========================================");
    }
}
