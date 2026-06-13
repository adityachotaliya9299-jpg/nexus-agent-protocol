// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {TaskMarketplace} from "../src/marketplace/TaskMarketplace.sol";

/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Deployment script for Phase 3 — TaskMarketplace
/// @dev forge script script/DeployTaskMarketplace.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
contract DeployTaskMarketplaceScript is Script {
    address constant AGENT_REGISTRY    = address(0); 
    address constant REPUTATION_ORACLE = address(0); 
    address constant ARBITRATOR        = address(0); 
    uint256 constant PLATFORM_FEE_BPS  = 250;        // 2.5%

    function run() external {
        require(AGENT_REGISTRY != address(0),    "Set AGENT_REGISTRY");
        require(REPUTATION_ORACLE != address(0), "Set REPUTATION_ORACLE");
        require(ARBITRATOR != address(0),        "Set ARBITRATOR");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Nexus Agent Protocol - Phase 3 Deployment ===");
        console.log("Deployer:          ", deployer);
        console.log("Network:           ", block.chainid);
        console.log("AgentRegistry:     ", AGENT_REGISTRY);
        console.log("ReputationOracle:  ", REPUTATION_ORACLE);
        console.log("Arbitrator:        ", ARBITRATOR);
        console.log("Platform Fee:      ", PLATFORM_FEE_BPS, "bps");

        vm.startBroadcast(deployerPrivateKey);

        TaskMarketplace marketplace = new TaskMarketplace(
            deployer,
            AGENT_REGISTRY,
            REPUTATION_ORACLE,
            ARBITRATOR,
            PLATFORM_FEE_BPS
        );

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployed Contracts ===");
        console.log("TaskMarketplace:   ", address(marketplace));
        console.log("");
        console.log("Post-deploy steps:");
        console.log("  1. oracle.setAuthorizedUpdater(marketplace, true)");
        console.log("  2. agentMemory.setAuthorizedWriter(marketplace, true)");
        console.log("  3. Verify on Etherscan");
        console.log("  4. Test with a real task posting");
    }
}
