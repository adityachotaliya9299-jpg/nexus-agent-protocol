// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ZKEscrow} from "../src/escrow/ZKEscrow.sol";

/// @title DeployZKEscrow
/// @notice Deploys ZKEscrow — the trustless ZK-gated payment escrow.
/// @author Aditya Chotaliya [adityachotaliya.xyz]
///
/// Usage:
///   forge script script/DeployZKEscrow.s.sol \
///     --rpc-url $SEPOLIA_RPC_URL \
///     --broadcast \
///     --verify \
///     --etherscan-api-key $ETHERSCAN_API_KEY \
///     -vvvv
///
/// Environment:
///   PRIVATE_KEY         - deployer
///   ARBITRATOR_ADDRESS  - arbitrator for disputed escrows
///   ZK_VERIFIER_ADDR    - deployed ZKVerifier (has groth16Verifier wired in)
///                         OR use GROTH16_VERIFIER_ADDR directly
contract DeployZKEscrow is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);
        address arbitrator  = vm.envOr("ARBITRATOR_ADDRESS", deployer);

        // Use Groth16Verifier directly for ZKEscrow
        // This is the auto-generated snarkjs verifier from Phase 9
        address groth16Verifier = vm.envOr(
            "GROTH16_VERIFIER_ADDR",
            address(0x68F76277A7a8991CE7ac7182AAA10a356dAaB48F)
        );

        console.log("==========================================");
        console.log("Deploying ZKEscrow");
        console.log("==========================================");
        console.log("Deployer:         ", deployer);
        console.log("Groth16Verifier:  ", groth16Verifier);
        console.log("Arbitrator:       ", arbitrator);

        vm.startBroadcast(deployerKey);

        ZKEscrow zkEscrow = new ZKEscrow(
            deployer,
            groth16Verifier,
            arbitrator
        );

        vm.stopBroadcast();

        console.log("");
        console.log("==========================================");
        console.log("ZKEscrow deployed:", address(zkEscrow));
        console.log("==========================================");
        console.log("Add to .env:");
        console.log("  ZK_ESCROW_ADDR=", address(zkEscrow));
        console.log("");
        console.log("How to use:");
        console.log("  1. Client: createEscrow{value: reward}(taskId, agentWallet, deadline)");
        console.log("  2. Client: setCommitment(escrowId, keccak256(resultHash, salt))");
        console.log("     (share salt with agent off-chain after task is assigned)");
        console.log("  3. Agent: generate Groth16 proof off-chain via scripts/zk/generate-proof.js");
        console.log("  4. Agent: releaseWithProof(escrowId, resultHash, salt, pA, pB, pC, pubSignals)");
        console.log("  5. ETH auto-released to agentWallet - no client approval needed");
        console.log("==========================================");
    }
}
