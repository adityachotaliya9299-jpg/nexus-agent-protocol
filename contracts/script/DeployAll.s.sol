// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";

import {AgentRegistry}        from "../src/AgentRegistry.sol";
import {AgentWalletFactory}   from "../src/AgentWalletFactory.sol";
import {ReputationOracle}     from "../src/reputation/ReputationOracle.sol";
import {AgentMemory}          from "../src/memory/AgentMemory.sol";
import {TaskMarketplace}      from "../src/marketplace/TaskMarketplace.sol";
import {ZKVerifier}           from "../src/zk/ZKVerifier.sol";
import {SubscriptionManager}  from "../src/subscriptions/SubscriptionManager.sol";
import {CrossChainBridge}     from "../src/bridge/CrossChainBridge.sol";

/// @title DeployAll
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Unified deployment script for the full Nexus Agent Protocol
/// @dev Deploys all 9 contracts in correct dependency order,
///      wires authorizations, and logs all addresses.
///
/// Usage:
///   # Dry run (no broadcast)
///   forge script script/DeployAll.s.sol --rpc-url $SEPOLIA_RPC_URL -vvvv
///
///   # Live deployment + verify
///   forge script script/DeployAll.s.sol \
///     --rpc-url $SEPOLIA_RPC_URL \
///     --broadcast \
///     --verify \
///     --etherscan-api-key $ETHERSCAN_API_KEY \
///     -vvvv
///
/// Environment variables required (.env):
///   PRIVATE_KEY          - Deployer private key
///   SEPOLIA_RPC_URL      - RPC endpoint
///   ETHERSCAN_API_KEY    - For contract verification
///   ARBITRATOR_ADDRESS   - Multisig for dispute resolution
///   CCIP_ROUTER          - Chainlink CCIP router on this chain
///   ENTRY_POINT          - ERC-4337 EntryPoint (standard: 0x5FF137D4...)
contract DeployAll is Script {
    // ============================================================
    //                  DEPLOYMENT CONFIGURATION
    // ============================================================

    // ── ERC-4337 EntryPoint (same on all EVM chains) ──────────
    address constant ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    // ── Chainlink CCIP Routers (per chain) ────────────────────
    // Ethereum Sepolia:  0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59
    // Polygon Mumbai:    0x1035CabC275068e0F4b745A29CEDf38E13aF41b1
    // Arbitrum Sepolia:  0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165
    // Base Sepolia:      0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93

    // ── CCIP Chain Selectors ──────────────────────────────────
    uint64 constant ETH_SEPOLIA_SELECTOR  = 16015286601757825753;
    uint64 constant POLYGON_SELECTOR      = 4051577828743386545;
    uint64 constant ARB_SELECTOR          = 4949039107694359620;
    uint64 constant BASE_SELECTOR         = 15971525489660198786;

    // ── Protocol parameters ───────────────────────────────────
    uint256 constant MARKETPLACE_FEE_BPS  = 250;   // 2.5%
    uint256 constant SUBSCRIPTION_FEE_BPS = 250;   // 2.5%
    uint256 constant ZK_QUORUM_THRESHOLD  = 6700;  // 67% of AVS operators
    uint64  constant THIS_CHAIN_SELECTOR  = ETH_SEPOLIA_SELECTOR;

    // ============================================================
    //                    DEPLOYED ADDRESSES
    //                  (filled in during run)
    // ============================================================

    AgentRegistry       public registry;
    AgentWalletFactory  public walletFactory;
    ReputationOracle    public oracle;
    AgentMemory         public agentMemory;
    TaskMarketplace     public marketplace;
    ZKVerifier          public zkVerifier;
    SubscriptionManager public subManager;
    CrossChainBridge    public bridge;

    // ============================================================
    //                         RUN
    // ============================================================

    function run() external {
        // ── Load config from environment ──────────────────────
        uint256 deployerKey   = vm.envUint("PRIVATE_KEY");
        address deployer      = vm.addr(deployerKey);
        address arbitrator    = vm.envOr("ARBITRATOR_ADDRESS", deployer);
        address ccipRouter    = vm.envOr("CCIP_ROUTER", address(0));
        address entryPoint    = vm.envOr("ENTRY_POINT", ENTRY_POINT);

        require(ccipRouter != address(0),
            "Set CCIP_ROUTER env var (Chainlink router for this chain)");

        _printHeader(deployer, arbitrator, ccipRouter, entryPoint);

        vm.startBroadcast(deployerKey);

        // ── PHASE 1: Foundation ───────────────────────────────
        console.log("\n[Phase 1A] Deploying AgentRegistry...");
        registry = new AgentRegistry(deployer);
        console.log("  AgentRegistry:       ", address(registry));

        console.log("[Phase 1B] Deploying AgentWalletFactory...");
        walletFactory = new AgentWalletFactory(entryPoint, address(registry));
        console.log("  AgentWalletFactory:  ", address(walletFactory));

        // ── PHASE 2: Reputation & Memory ─────────────────────
        console.log("\n[Phase 2A] Deploying ReputationOracle...");
        oracle = new ReputationOracle(deployer, address(registry));
        console.log("  ReputationOracle:    ", address(oracle));

        console.log("[Phase 2B] Deploying AgentMemory...");
        agentMemory = new AgentMemory(deployer, address(registry));
        console.log("  AgentMemory:         ", address(agentMemory));

        // ── PHASE 3: Task Marketplace ─────────────────────────
        console.log("\n[Phase 3] Deploying TaskMarketplace...");
        marketplace = new TaskMarketplace(
            deployer,
            address(registry),
            address(oracle),
            arbitrator,
            MARKETPLACE_FEE_BPS
        );
        console.log("  TaskMarketplace:     ", address(marketplace));

        // ── PHASE 4: ZK Verification ──────────────────────────
        console.log("\n[Phase 4] Deploying ZKVerifier...");
        zkVerifier = new ZKVerifier(
            deployer,
            address(registry),
            address(oracle),
            ZK_QUORUM_THRESHOLD
        );
        console.log("  ZKVerifier:          ", address(zkVerifier));

        // ── PHASE 5: Subscriptions ────────────────────────────
        console.log("\n[Phase 5] Deploying SubscriptionManager...");
        subManager = new SubscriptionManager(
            deployer,
            address(registry),
            SUBSCRIPTION_FEE_BPS
        );
        console.log("  SubscriptionManager: ", address(subManager));

        // ── PHASE 6: Cross-Chain Bridge ───────────────────────
        console.log("\n[Phase 6] Deploying CrossChainBridge...");
        bridge = new CrossChainBridge(
            deployer,
            address(registry),
            address(oracle),
            ccipRouter,
            THIS_CHAIN_SELECTOR
        );
        console.log("  CrossChainBridge:    ", address(bridge));

        // ── WIRE AUTHORIZATIONS ───────────────────────────────
        console.log("\n[Wiring] Setting up cross-contract authorizations...");

        // Registry: authorize oracle to update reputation
        registry.setReputationUpdater(address(oracle), true);
        console.log("  registry.setReputationUpdater(oracle)       [OK]");

        // Oracle: authorize marketplace, zkVerifier, bridge
        oracle.setAuthorizedUpdater(address(marketplace), true);
        console.log("  oracle.setAuthorizedUpdater(marketplace)    [OK]");

        oracle.setAuthorizedUpdater(address(zkVerifier), true);
        console.log("  oracle.setAuthorizedUpdater(zkVerifier)     [OK]");

        oracle.setAuthorizedUpdater(address(bridge), true);
        console.log("  oracle.setAuthorizedUpdater(bridge)         [OK]");

        // Memory: authorize marketplace to write task history
        agentMemory.setAuthorizedWriter(address(marketplace), true);
        console.log("  memory.setAuthorizedWriter(marketplace)     [OK]");

        // Bridge: add supported chains
        bridge.addSupportedChain(POLYGON_SELECTOR, address(0), "Polygon PoS");
        bridge.addSupportedChain(ARB_SELECTOR,     address(0), "Arbitrum One");
        bridge.addSupportedChain(BASE_SELECTOR,    address(0), "Base");
        console.log("  bridge.addSupportedChain(Polygon, Arb, Base)[OK]");

        vm.stopBroadcast();

        // ── PRINT SUMMARY ─────────────────────────────────────
        _printSummary(deployer, arbitrator);
    }

    // ============================================================
    //                     PRINT HELPERS
    // ============================================================

    function _printHeader(
        address deployer,
        address arbitrator,
        address ccipRouter,
        address entryPoint
    ) internal view {
        console.log("");
        console.log("================================================");
        console.log("NEXUS AGENT PROTOCOL DEPLOYMENT");
        console.log("================================================");
        console.log("Network:     ", block.chainid);
        console.log("Block:       ", block.number);
        console.log("Deployer:    ", deployer);
        console.log("Arbitrator:  ", arbitrator);
        console.log("CCIP Router: ", ccipRouter);
        console.log("EntryPoint:  ", entryPoint);
        console.log("================================================");
    }

    function _printSummary(address deployer, address arbitrator) internal view {
        console.log("");
        console.log("================================================");
        console.log("DEPLOYMENT SUMMARY WITH ADDRESSES");
        console.log("================================================");
        console.log("");
        console.log("  -- Phase 1: Foundation --");
        console.log("  AgentRegistry:       ", address(registry));
        console.log("  AgentWalletFactory:  ", address(walletFactory));
        console.log("");
        console.log("  -- Phase 2: Reputation & Memory --");
        console.log("  ReputationOracle:    ", address(oracle));
        console.log("  AgentMemory:         ", address(agentMemory));
        console.log("");
        console.log("  -- Phase 3: Marketplace --");
        console.log("  TaskMarketplace:     ", address(marketplace));
        console.log("");
        console.log("  -- Phase 4: ZK --");
        console.log("  ZKVerifier:          ", address(zkVerifier));
        console.log("");
        console.log("  -- Phase 5: Subscriptions --");
        console.log("  SubscriptionManager: ", address(subManager));
        console.log("");
        console.log("  -- Phase 6: Bridge --");
        console.log("  CrossChainBridge:    ", address(bridge));
        console.log("");
        console.log("================================================");
        console.log("  Protocol Owner:  ", deployer);
        console.log("  Arbitrator:      ", arbitrator);
        console.log("================================================");
        console.log("");
        console.log("  NEXT STEPS:");
        console.log("  1. Verify all contracts on Etherscan");
        console.log("  2. Register ZK verification keys");
        console.log("  3. Register AVS operators for ZKVerifier");
        console.log("  4. Update bridge addresses for each remote chain");
        console.log("  5. Transfer protocolOwner to multisig");
        console.log("  6. Update frontend .env with these addresses");
        console.log("================================================");
    }
}
