// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AgentIdentityNFT} from "../src/nft/AgentIdentityNFT.sol";
import {AgentSkillNFT} from "../src/nft/AgentSkillNFT.sol";

/// @title DeployNFTs
/// @notice Deploys AgentIdentityNFT (ERC-721) and AgentSkillNFT (ERC-1155).
///
/// Usage:
///   forge script script/DeployNFTs.s.sol \
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
contract DeployNFTs is Script {
    function run() external {
        uint256 deployerKey      = vm.envUint("PRIVATE_KEY");
        address deployer         = vm.addr(deployerKey);
        address agentRegistry    = vm.envAddress("AGENT_REGISTRY_ADDR");
        address reputationOracle = vm.envAddress("REPUTATION_ORACLE_ADDR");
        address taskMarketplace  = vm.envAddress("TASK_MARKETPLACE_ADDR");

        console.log("==========================================");
        console.log("Deploying Nexus NFT Contracts");
        console.log("==========================================");
        console.log("Deployer:         ", deployer);
        console.log("AgentRegistry:    ", agentRegistry);
        console.log("ReputationOracle: ", reputationOracle);
        console.log("TaskMarketplace:  ", taskMarketplace);

        vm.startBroadcast(deployerKey);

        // 1. Deploy Identity NFT (ERC-721 soulbound)
        AgentIdentityNFT identityNFT = new AgentIdentityNFT(
            deployer,
            agentRegistry,
            reputationOracle
        );
        console.log("AgentIdentityNFT deployed:", address(identityNFT));

        // 2. Deploy Skill NFT (ERC-1155)
        AgentSkillNFT skillNFT = new AgentSkillNFT(
            deployer,
            agentRegistry
        );
        console.log("AgentSkillNFT deployed:", address(skillNFT));

        // 3. Authorize marketplace to mint skill badges on task completion
        identityNFT.setMinter(taskMarketplace, true);
        skillNFT.setMinter(taskMarketplace, true);
        console.log("  marketplace authorized as minter [OK]");

        // 4. Also authorize deployer for manual minting (testing)
        identityNFT.setMinter(deployer, true);
        skillNFT.setMinter(deployer, true);
        console.log("  deployer authorized as minter [OK]");

        vm.stopBroadcast();

        console.log("");
        console.log("==========================================");
        console.log("NFT CONTRACTS DEPLOYED");
        console.log("==========================================");
        console.log("AgentIdentityNFT: ", address(identityNFT));
        console.log("AgentSkillNFT:    ", address(skillNFT));
        console.log("");
        console.log("Add to .env:");
        console.log("  IDENTITY_NFT_ADDR=", address(identityNFT));
        console.log("  SKILL_NFT_ADDR=",    address(skillNFT));
        console.log("");
        console.log("Next steps:");
        console.log("  1. Wire identity minting into AgentRegistry.registerAgent()");
        console.log("  2. Wire skill minting into TaskMarketplace.approveWork()");
        console.log("  3. Update frontend to display NFTs via wagmi useReadContract");
        console.log("==========================================");
    }
}
