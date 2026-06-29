// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AgentComposability} from "../src/composability/AgentComposability.sol";

/// @title DeployAgentComposability
/// @notice Deploys the AgentComposability contract.
/// @author Aditya Chotaliya [adityachotaliya.xyz]
///
/// Usage:
///   forge script script/DeployAgentComposability.s.sol \
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
contract DeployAgentComposability is Script {
    function run() external {
        uint256 deployerKey      = vm.envUint("PRIVATE_KEY");
        address deployer         = vm.addr(deployerKey);
        address agentRegistry    = vm.envAddress("AGENT_REGISTRY_ADDR");
        address reputationOracle = vm.envAddress("REPUTATION_ORACLE_ADDR");

        console.log("==========================================");
        console.log("Deploying AgentComposability");
        console.log("==========================================");
        console.log("Deployer:         ", deployer);
        console.log("AgentRegistry:    ", agentRegistry);
        console.log("ReputationOracle: ", reputationOracle);

        vm.startBroadcast(deployerKey);

        AgentComposability comp = new AgentComposability(
            deployer,
            agentRegistry,
            reputationOracle
        );

        vm.stopBroadcast();

        console.log("");
        console.log("==========================================");
        console.log("AgentComposability deployed:", address(comp));
        console.log("==========================================");
        console.log("Add to .env:");
        console.log("  COMPOSABILITY_ADDR=", address(comp));
        console.log("");
        console.log("Next steps:");
        console.log("  1. Authorize ReputationOracle to accept updates from this contract");
        console.log("     cast send $REPUTATION_ORACLE_ADDR 'setAuthorizedUpdater(address,bool)' \\");
        console.log("     ", address(comp), " true --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY");
        console.log("==========================================");
    }
}
