// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {CrossChainBridge} from "../src/bridge/CrossChainBridge.sol";

/// @notice Deployment script for CrossChainBridge
/// @dev Deploy on each chain where agents operate
///      forge script script/DeployCrossChainBridge.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
contract DeployCrossChainBridgeScript is Script {
    // ============================================================
    //              CHAINLINK CCIP CHAIN SELECTORS
    // ============================================================
    // Mainnet selectors — change for testnet deployments
    uint64 constant ETH_SELECTOR     = 5009297550715157269;
    uint64 constant POLYGON_SELECTOR = 4051577828743386545;
    uint64 constant ARB_SELECTOR     = 4949039107694359620;
    uint64 constant BASE_SELECTOR    = 15971525489660198786;

    // ============================================================
    //     FILL THESE IN FROM PREVIOUS PHASE DEPLOYMENTS
    // ============================================================
    address constant AGENT_REGISTRY    = address(0); 
    address constant REPUTATION_ORACLE = address(0); 

    // CCIP Router addresses per chain (from Chainlink docs)
    // Ethereum Sepolia: 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59
    // Polygon Mumbai:   0x1035CabC275068e0F4b745A29CEDf38E13aF41b1
    address constant CCIP_ROUTER      = address(0); 

    function run() external {
        require(AGENT_REGISTRY    != address(0), "Set AGENT_REGISTRY");
        require(REPUTATION_ORACLE != address(0), "Set REPUTATION_ORACLE");
        require(CCIP_ROUTER       != address(0), "Set CCIP_ROUTER for this chain");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        uint64 chainSelector = _getChainSelector(block.chainid);

        console.log("=== Nexus Agent Protocol - Phase 6 Deployment ===");
        console.log("Deployer:          ", deployer);
        console.log("Network:           ", block.chainid);
        console.log("Chain Selector:    ", chainSelector);
        console.log("AgentRegistry:     ", AGENT_REGISTRY);
        console.log("ReputationOracle:  ", REPUTATION_ORACLE);
        console.log("CCIP Router:       ", CCIP_ROUTER);

        vm.startBroadcast(deployerPrivateKey);

        CrossChainBridge bridge = new CrossChainBridge(
            deployer,
            AGENT_REGISTRY,
            REPUTATION_ORACLE,
            CCIP_ROUTER,
            chainSelector
        );

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployed Contracts ===");
        console.log("CrossChainBridge:  ", address(bridge));
        console.log("");
        console.log("Post-deploy steps:");
        console.log("  1. Verify on Etherscan");
        console.log("  2. Add supported chains:");
        console.log("     bridge.addSupportedChain(POLYGON_SELECTOR, polygonBridgeAddr, 'Polygon')");
        console.log("     bridge.addSupportedChain(ARB_SELECTOR, arbBridgeAddr, 'Arbitrum')");
        console.log("     bridge.addSupportedChain(BASE_SELECTOR, baseBridgeAddr, 'Base')");
        console.log("  3. Fund bridge with LINK for CCIP fees (or use native token mode)");
        console.log("  4. Deploy this contract on all other chains, link bridges together");
    }

    function _getChainSelector(uint256 chainId) internal pure returns (uint64) {
        if (chainId == 1)     return ETH_SELECTOR;     // Ethereum mainnet
        if (chainId == 137)   return POLYGON_SELECTOR; // Polygon
        if (chainId == 42161) return ARB_SELECTOR;     // Arbitrum
        if (chainId == 8453)  return BASE_SELECTOR;    // Base
        // Testnets
        if (chainId == 11155111) return 16015286601757825753; // Sepolia
        return uint64(chainId); // fallback
    }
}
