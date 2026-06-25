// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {NexusServiceManager} from "../src/avs/NexusServiceManager.sol";

/// @title DeployNexusServiceManager
/// @notice Deploys NexusServiceManager and registers Nexus as an EigenLayer AVS.
///
/// Prerequisites:
///   1. All Nexus contracts deployed (DeployAll.s.sol)
///   2. Sepolia ETH in deployer wallet
///   3. METADATA_URI hosted publicly (GitHub Pages or IPFS)
///
/// Usage:
///   forge script script/DeployNexusServiceManager.s.sol \
///     --rpc-url $SEPOLIA_RPC_URL \
///     --broadcast \
///     --verify \
///     --etherscan-api-key $ETHERSCAN_API_KEY \
///     -vvvv
///
/// Environment variables required:
///   PRIVATE_KEY         - deployer key
///   ZK_VERIFIER_ADDR    - deployed ZKVerifier
///   AGENT_REGISTRY_ADDR - deployed AgentRegistry
///   AVS_METADATA_URI    - public URL to metadata JSON (see metadata template below)
///
/// AVS Metadata JSON template (host this at AVS_METADATA_URI):
/// {
///   "name": "Nexus Agent Protocol",
///   "website": "https://nexusagent.vercel.app",
///   "description": "The on-chain operating system for autonomous AI agents. ZK-verified task completion.",
///   "logo": "https://nexusagent.vercel.app/logo.png",
///   "twitter": "https://twitter.com/AdityaChot15838"
/// }
contract DeployNexusServiceManager is Script {

   
    address constant AVS_DIRECTORY_SEPOLIA  = 0xa789c91ECDdae96865913130B786140Ee17aF545;

    function run() external {
        uint256 deployerKey   = vm.envUint("PRIVATE_KEY");
        address deployer      = vm.addr(deployerKey);
        address zkVerifier    = vm.envAddress("ZK_VERIFIER_ADDR");
        address agentRegistry = vm.envAddress("AGENT_REGISTRY_ADDR");
        string memory metaURI = vm.envOr(
            "AVS_METADATA_URI",
            string("https://raw.githubusercontent.com/adityachotaliya9299-jpg/nexus-agent-protocol/main/avs-metadata.json")
        );

        console.log("==========================================");
        console.log("Deploying Nexus as EigenLayer AVS");
        console.log("==========================================");
        console.log("Deployer:      ", deployer);
        console.log("AVSDirectory:  ", AVS_DIRECTORY_SEPOLIA);
        console.log("ZKVerifier:    ", zkVerifier);
        console.log("AgentRegistry: ", agentRegistry);
        console.log("Metadata URI:  ", metaURI);
        console.log("==========================================");

        vm.startBroadcast(deployerKey);

        NexusServiceManager sm = new NexusServiceManager(
            deployer,
            AVS_DIRECTORY_SEPOLIA,
            zkVerifier,
            agentRegistry,
            metaURI
        );

        console.log("NexusServiceManager deployed:", address(sm));

        vm.stopBroadcast();

        console.log("");
        console.log("==========================================");
        console.log("NEXUS IS NOW AN EIGENLAYER AVS");
        console.log("==========================================");
        console.log("ServiceManager: ", address(sm));
        console.log("");
        console.log("Next steps:");
        console.log("1. Add to .env: SERVICE_MANAGER_ADDR=", address(sm));
        console.log("2. Host avs-metadata.json at the metadata URI");
        console.log("3. Verify: https://holesky.eigenlayer.xyz/avs");
        console.log("4. Register operators: see scripts/avs/register-operator.js");
        console.log("==========================================");
    }
}
