// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {L2Bridge} from "../src/bridge/L2Bridge.sol";

/// @title DeployL2Bridge
/// @notice Deploys L2Bridge on EITHER Sepolia (L1) or Base Sepolia (L2).
///         Run twice — once on each chain — then call setPeerBridge().
///
/// Step 1: Deploy on Sepolia (L1):
///   forge script script/DeployL2Bridge.s.sol \
///     --rpc-url $SEPOLIA_RPC_URL \
///     --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY \
///     -vvvv
///   → note L1BridgeAddress
///
/// Step 2: Deploy on Base Sepolia (L2):
///   L2_MODE=true \
///   forge script script/DeployL2Bridge.s.sol \
///     --rpc-url $BASE_SEPOLIA_RPC_URL \
///     --broadcast --verify \
///     --verifier-url https://api-sepolia.basescan.org/api \
///     --etherscan-api-key $BASESCAN_API_KEY \
///     -vvvv
///   → note L2BridgeAddress
///
/// Step 3: Wire peers:
///   cast send <L1BridgeAddress> "setPeerBridge(address)" <L2BridgeAddress> \
///     --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
///   cast send <L2BridgeAddress> "setPeerBridge(address)" <L1BridgeAddress> \
///     --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
///
/// Step 4: Bridge your rep from L1 → L2:
///   cast send <L1BridgeAddress> "bridgeReputation(uint256)" 1 \
///     --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
contract DeployL2Bridge is Script {
    function run() external {
        uint256 deployerKey   = vm.envUint("PRIVATE_KEY");
        address deployer      = vm.addr(deployerKey);
        bool    isL2Mode      = vm.envOr("L2_MODE", false);
        address agentRegistry = vm.envAddress("AGENT_REGISTRY_ADDR");
        address repOracle     = vm.envAddress("REPUTATION_ORACLE_ADDR");

        string memory chainName = isL2Mode ? "Base Sepolia (L2)" : "Ethereum Sepolia (L1)";

        console.log("==========================================");
        console.log("Deploying L2Bridge on:", chainName);
        console.log("==========================================");
        console.log("Deployer:       ", deployer);
        console.log("AgentRegistry:  ", agentRegistry);
        console.log("ReputationOracle:", repOracle);
        console.log("isL2:           ", isL2Mode);

        vm.startBroadcast(deployerKey);

        L2Bridge bridge = new L2Bridge(
            deployer,
            agentRegistry,
            repOracle,
            isL2Mode
        );

        vm.stopBroadcast();

        console.log("");
        console.log("==========================================");
        console.log("L2Bridge deployed:", address(bridge));
        console.log("==========================================");
        if (isL2Mode) {
            console.log("This is the L2 (Base) bridge.");
            console.log("Set peer to the L1 bridge address:");
            console.log("  L2_BRIDGE_ADDR=", address(bridge));
        } else {
            console.log("This is the L1 (Sepolia) bridge.");
            console.log("Set peer to the L2 bridge address:");
            console.log("  L1_BRIDGE_ADDR=", address(bridge));
        }
        console.log("Then call setPeerBridge(peerAddress) on both.");
        console.log("==========================================");
    }
}
