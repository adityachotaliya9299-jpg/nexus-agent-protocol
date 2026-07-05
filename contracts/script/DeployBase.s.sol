// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AgentRegistry}    from "../src/AgentRegistry.sol";
import {ReputationOracle} from "../src/reputation/ReputationOracle.sol";
import {TaskMarketplace}  from "../src/marketplace/TaskMarketplace.sol";
import {AgentStaking}     from "../src/staking/AgentStaking.sol";
import {ZKEscrow}         from "../src/escrow/ZKEscrow.sol";
import {Groth16Verifier}  from "../src/zk/Groth16Verifier.sol";
import {AgentComposability} from "../src/composability/AgentComposability.sol";
import {ContextualReputation} from "../src/reputation/ContextualReputation.sol";
import {AgentDiscovery}   from "../src/discovery/AgentDiscovery.sol";
import {ProtocolGuard}    from "../src/security/ProtocolGuard.sol";
import {ResultStorage}    from "../src/storage/ResultStorage.sol";

/// @title DeployBase
/// @notice Deploys the core Nexus stack to Base Sepolia.
///
/// @dev Base Sepolia differences from Ethereum Sepolia:
///   - chainId:      84532
///   - Native token: ETH (same)
///   - Block time:   ~2 seconds (vs 12s on Ethereum)
///   - Gas:          ~10x cheaper than Ethereum
///   - No EigenLayer AVS (EigenLayer not on Base yet)
///   - No Chainlink Functions (skipped)
///
/// Base Sepolia RPC: https://sepolia.base.org
/// Explorer:        https://sepolia.basescan.org
/// Bridge:          https://superbridge.app/base-sepolia
/// Faucet:          https://faucet.quicknode.com/base/sepolia
///
/// Usage:
///   forge script script/DeployBase.s.sol \
///     --rpc-url $BASE_SEPOLIA_RPC_URL \
///     --broadcast \
///     --verify \
///     --verifier-url https://api-sepolia.basescan.org/api \
///     --etherscan-api-key $BASESCAN_API_KEY \
///     -vvvv
contract DeployBase is Script {

    // ── Base Sepolia config ───────────────────────────────────────

    uint256 constant CHAIN_ID         = 84532;
    uint256 constant PLATFORM_FEE_BPS = 250;   // 2.5%

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);
        address arbitrator  = vm.envOr("ARBITRATOR_ADDRESS", deployer);

        require(block.chainid == CHAIN_ID, "Wrong chain — use Base Sepolia RPC");

        console.log("==========================================");
        console.log("Deploying Nexus to Base Sepolia");
        console.log("==========================================");
        console.log("Deployer:   ", deployer);
        console.log("Chain ID:   ", block.chainid);
        console.log("Arbitrator: ", arbitrator);

        vm.startBroadcast(deployerKey);

        // ── 1. Core identity ──────────────────────────────────────
        AgentRegistry registry = new AgentRegistry(deployer);
        console.log("[1] AgentRegistry:       ", address(registry));

        // ── 2. Reputation ─────────────────────────────────────────
        ReputationOracle oracle = new ReputationOracle(deployer, address(registry));
        console.log("[2] ReputationOracle:    ", address(oracle));

        ContextualReputation contextualRep = new ContextualReputation(deployer, address(registry));
        console.log("[3] ContextualReputation:", address(contextualRep));

        // ── 3. ZK verification ────────────────────────────────────
        Groth16Verifier groth16 = new Groth16Verifier();
        console.log("[4] Groth16Verifier:     ", address(groth16));

        // ── 4. Economic layer ─────────────────────────────────────
        TaskMarketplace marketplace = new TaskMarketplace(
            deployer, address(registry), address(oracle),
            arbitrator, PLATFORM_FEE_BPS
        );
        console.log("[5] TaskMarketplace:     ", address(marketplace));

        AgentStaking staking = new AgentStaking(
            deployer, address(registry), address(oracle), deployer
        );
        console.log("[6] AgentStaking:        ", address(staking));

        ZKEscrow zkescrow = new ZKEscrow(deployer, address(groth16), arbitrator);
        console.log("[7] ZKEscrow:            ", address(zkescrow));

        // ── 5. Composability ──────────────────────────────────────
        AgentComposability composability = new AgentComposability(
            deployer, address(registry), address(oracle)
        );
        console.log("[8] AgentComposability:  ", address(composability));

        // ── 6. Discovery ──────────────────────────────────────────
        AgentDiscovery discovery = new AgentDiscovery(
            deployer, address(registry), address(oracle),
            address(contextualRep), address(staking)
        );
        console.log("[9] AgentDiscovery:      ", address(discovery));

        // ── 7. Storage ────────────────────────────────────────────
        ResultStorage resultStorage = new ResultStorage(deployer, address(registry));
        console.log("[10] ResultStorage:      ", address(resultStorage));

        // ── 8. Security ───────────────────────────────────────────
        ProtocolGuard guard = new ProtocolGuard(deployer);
        guard.addGuardian(deployer);
        console.log("[11] ProtocolGuard:      ", address(guard));

        // ── Wire authorizations ───────────────────────────────────
        oracle.setAuthorizedUpdater(address(marketplace), true);
        oracle.setAuthorizedUpdater(address(composability), true);
        registry.setReputationUpdater(address(oracle), true);
        contextualRep.setAuthorized(address(marketplace), true);
        staking.setAuthorized(address(marketplace), true);
        staking.setAuthorized(arbitrator, true);
        discovery.setAuthorized(deployer, true);
        resultStorage.setAuthorized(address(marketplace), true);

        console.log("[OK] Authorizations wired");

        vm.stopBroadcast();

        console.log("");
        console.log("==========================================");
        console.log("BASE SEPOLIA DEPLOYMENT COMPLETE");
        console.log("==========================================");
        console.log("AgentRegistry:        ", address(registry));
        console.log("ReputationOracle:     ", address(oracle));
        console.log("ContextualReputation: ", address(contextualRep));
        console.log("Groth16Verifier:      ", address(groth16));
        console.log("TaskMarketplace:      ", address(marketplace));
        console.log("AgentStaking:         ", address(staking));
        console.log("ZKEscrow:             ", address(zkescrow));
        console.log("AgentComposability:   ", address(composability));
        console.log("AgentDiscovery:       ", address(discovery));
        console.log("ResultStorage:        ", address(resultStorage));
        console.log("ProtocolGuard:        ", address(guard));
        console.log("==========================================");
        console.log("Explorer: https://sepolia.basescan.org");
        console.log("Bridge:   https://superbridge.app/base-sepolia");
        console.log("==========================================");
    }
}
