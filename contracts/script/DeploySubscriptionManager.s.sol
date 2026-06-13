// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {SubscriptionManager} from "../src/subscriptions/SubscriptionManager.sol";

/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Deployment script  - SubscriptionManager
/// @dev forge script script/DeploySubscriptionManager.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
contract DeploySubscriptionManagerScript is Script {
    address constant AGENT_REGISTRY   = address(0); // TODO: Phase 1A
    uint256 constant PLATFORM_FEE_BPS = 250;        // 2.5%

    function run() external {
        require(AGENT_REGISTRY != address(0), "Set AGENT_REGISTRY");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Nexus Agent Protocol - Phase 5 Deployment ===");
        console.log("Deployer:         ", deployer);
        console.log("Network:          ", block.chainid);
        console.log("AgentRegistry:    ", AGENT_REGISTRY);
        console.log("Platform Fee:     ", PLATFORM_FEE_BPS, "bps");

        vm.startBroadcast(deployerPrivateKey);

        SubscriptionManager subManager = new SubscriptionManager(
            deployer,
            AGENT_REGISTRY,
            PLATFORM_FEE_BPS
        );

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployed Contracts ===");
        console.log("SubscriptionManager:", address(subManager));
        console.log("");
        console.log("Post-deploy steps:");
        console.log("  1. Verify on Etherscan");
        console.log("  2. Agents call createPlan() to list their services");
        console.log("  3. Clients call subscribe() to start paying");
        console.log("  4. Set up keeper to call processPayment() each period");
    }
}
