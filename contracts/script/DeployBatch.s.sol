// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ResultStorage}   from "../src/storage/ResultStorage.sol";
import {AgentDAO}        from "../src/dao/AgentDAO.sol";
import {CommunityGrants} from "../src/grants/CommunityGrants.sol";

/// @title DeployBatch
/// @notice Deploys ResultStorage, AgentDAO, and CommunityGrants.
///
/// Usage:
///   forge script script/DeployBatch.s.sol \
///     --rpc-url $SEPOLIA_RPC_URL \
///     --broadcast \
///     --verify \
///     --etherscan-api-key $ETHERSCAN_API_KEY \
///     -vvvv
contract DeployBatch is Script {
    function run() external {
        uint256 deployerKey      = vm.envUint("PRIVATE_KEY");
        address deployer         = vm.addr(deployerKey);
        address agentRegistry    = vm.envAddress("AGENT_REGISTRY_ADDR");
        address reputationOracle = vm.envAddress("REPUTATION_ORACLE_ADDR");
        address taskMarketplace  = vm.envAddress("TASK_MARKETPLACE_ADDR");

        console.log("==========================================");
        console.log("Deploying: ResultStorage + AgentDAO + CommunityGrants");
        console.log("==========================================");
        console.log("Deployer:    ", deployer);
        console.log("Registry:    ", agentRegistry);
        console.log("Oracle:      ", reputationOracle);
        console.log("Marketplace: ", taskMarketplace);

        vm.startBroadcast(deployerKey);

        // 1. Result Storage (Arweave anchoring)
        ResultStorage resultStorage = new ResultStorage(deployer, agentRegistry);
        resultStorage.setAuthorized(taskMarketplace, true);
        console.log("ResultStorage:   ", address(resultStorage));

        // 2. Agent DAO (multi-agent coordination)
        AgentDAO agentDAO = new AgentDAO(deployer, agentRegistry);
        console.log("AgentDAO:        ", address(agentDAO));

        // 3. Community Grants (fee routing + grants)
        CommunityGrants communityGrants = new CommunityGrants(
            deployer, agentRegistry, reputationOracle
        );
        console.log("CommunityGrants: ", address(communityGrants));

        vm.stopBroadcast();

        console.log("");
        console.log("==========================================");
        console.log("DEPLOYED");
        console.log("==========================================");
        console.log("Add to .env:");
        console.log("  RESULT_STORAGE_ADDR=", address(resultStorage));
        console.log("  AGENT_DAO_ADDR=",      address(agentDAO));
        console.log("  COMMUNITY_GRANTS_ADDR=", address(communityGrants));
        console.log("==========================================");
    }
}
