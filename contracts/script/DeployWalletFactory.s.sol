// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AgentWallet} from "../src/AgentWallet.sol";
import {AgentWalletFactory} from "../src/AgentWalletFactory.sol";

/// @notice Deployment script for Phase 1B — AgentWallet + AgentWalletFactory
/// @dev Run after Phase 1A (AgentRegistry must already be deployed)
///      forge script script/DeployWalletFactory.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
contract DeployWalletFactoryScript is Script {

    /// @dev The AgentRegistry address deployed in Phase 1A
    address constant AGENT_REGISTRY = address(0); // TODO: fill after Phase 1A deploy

    /// @dev Standard ERC-4337 EntryPoint v0.6 on Sepolia and all major chains
    address constant ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    function run() external {
        require(AGENT_REGISTRY != address(0), "Set AGENT_REGISTRY address first");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Nexus Agent Protocol - Phase 1B Deployment ===");
        console.log("Deployer:         ", deployer);
        console.log("Network:          ", block.chainid);
        console.log("AgentRegistry:    ", AGENT_REGISTRY);
        console.log("EntryPoint:       ", ENTRY_POINT);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the factory
        AgentWalletFactory factory = new AgentWalletFactory(ENTRY_POINT, AGENT_REGISTRY);

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployed Contracts ===");
        console.log("AgentWalletFactory:", address(factory));
        console.log("");
        console.log("Next steps:");
        console.log("  1. Verify on Etherscan");
        console.log("  2. Registered agents can call factory.deployWallet()");
        console.log("  3. Call registry.setAgentWallet() to link wallet to agent profile");
        console.log("  4. Phase 2: Deploy ReputationOracle");

        // Show a sample computed address for deployer if registered
        address predicted = factory.computeWalletAddress(deployer, 1, bytes32(0));
        console.log("  Sample wallet address for deployer (agentId=1):", predicted);
    }
}
