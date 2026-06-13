// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";

/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Deployment script for  — AgentRegistry
/// @dev Run: forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Nexus Agent Protocol - Phase 1A Deployment ===");
        console.log("Deployer:       ", deployer);
        console.log("Network:        ", block.chainid);
        console.log("Block:          ", block.number);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy AgentRegistry with deployer as protocol owner
        AgentRegistry registry = new AgentRegistry(deployer);

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployed Contracts ===");
        console.log("AgentRegistry:  ", address(registry));
        console.log("");
        console.log("Next steps:");
        console.log("  1. Verify on Etherscan");
        console.log("  2. Deploy AgentWalletFactory (Phase 1B)");
        console.log("  3. Update frontend .env with contract addresses");
    }
}
