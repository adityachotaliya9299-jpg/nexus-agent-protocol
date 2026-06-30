// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AgentInference} from "../src/chainlink/AgentInference.sol";

/// @title DeployAgentInference
/// @notice Deploys AgentInference Chainlink Functions consumer.
///
/// Prerequisites:
///   1. Create a Chainlink Functions subscription at functions.chain.link
///   2. Fund subscription with LINK
///   3. Note the subscription ID
///
/// Usage:
///   forge script script/DeployAgentInference.s.sol \
///     --rpc-url $SEPOLIA_RPC_URL \
///     --broadcast \
///     --verify \
///     --etherscan-api-key $ETHERSCAN_API_KEY \
///     -vvvv
///
/// Environment:
///   PRIVATE_KEY            - deployer
///   AGENT_REGISTRY_ADDR    - deployed AgentRegistry
///   CHAINLINK_SUB_ID       - your Chainlink Functions subscription ID (uint64)
///
/// Post-deploy steps (see script output):
///   1. Add contract as consumer in Chainlink Functions dashboard
///   2. Upload encrypted secrets via Chainlink CLI
///   3. Call setEncryptedSecretsRef() with the DON-hosted secrets reference
contract DeployAgentInference is Script {
    function run() external {
        uint256 deployerKey   = vm.envUint("PRIVATE_KEY");
        address deployer      = vm.addr(deployerKey);
        address agentRegistry = vm.envAddress("AGENT_REGISTRY_ADDR");
        uint64  subId         = uint64(vm.envOr("CHAINLINK_SUB_ID", uint256(0)));

        console.log("==========================================");
        console.log("Deploying AgentInference (Chainlink Functions)");
        console.log("==========================================");
        console.log("Deployer:         ", deployer);
        console.log("AgentRegistry:    ", agentRegistry);
        console.log("Subscription ID:  ", subId);
        console.log("Functions Router: 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0");

        vm.startBroadcast(deployerKey);

        AgentInference inf = new AgentInference(
            deployer,
            agentRegistry,
            subId
        );

        vm.stopBroadcast();

        console.log("");
        console.log("==========================================");
        console.log("AgentInference deployed:", address(inf));
        console.log("==========================================");
        console.log("");
        console.log("REQUIRED POST-DEPLOY STEPS:");
        console.log("");
        console.log("1. Add this contract as a consumer in your Chainlink subscription:");
        console.log("   https://functions.chain.link (Sepolia)");
        console.log("   Consumer address:", address(inf));
        console.log("");
        console.log("2. Upload encrypted secrets (your OpenAI API key) to DON:");
        console.log("   npx @chainlink/env-enc set-pw");
        console.log("   npx @chainlink/env-enc set OPENAI_API_KEY <your_key>");
        console.log("   node scripts/uploadSecrets.js --network sepolia --subid", subId);
        console.log("");
        console.log("3. Call setEncryptedSecretsRef() with the returned reference bytes");
        console.log("");
        console.log("4. Add to .env:");
        console.log("   INFERENCE_ADDR=", address(inf));
        console.log("==========================================");
    }
}
