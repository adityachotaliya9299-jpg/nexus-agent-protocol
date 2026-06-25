// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Groth16Verifier} from "../src/zk/Groth16Verifier.sol";
import {ZKVerifier} from "../src/zk/ZKVerifier.sol";

/// @title DeployGroth16Verifier
/// @notice Deploys the snarkjs-generated Groth16Verifier and wires it
///         into the already-deployed ZKVerifier contract.
///
/// Prerequisites:
///   1. Run scripts/zk/setup-circuit.sh to generate Groth16Verifier.sol
///   2. ZKVerifier must already be deployed (Phase 8)
///
/// Usage:
///   forge script script/DeployGroth16Verifier.s.sol \
///     --rpc-url $SEPOLIA_RPC_URL \
///     --broadcast \
///     --verify \
///     --etherscan-api-key $ETHERSCAN_API_KEY \
///     -vvvv
///
/// Environment:
///   PRIVATE_KEY       - deployer key
///   ZK_VERIFIER_ADDR  - the deployed ZKVerifier address from Phase 8
contract DeployGroth16Verifier is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address zkVerifierAddr = vm.envAddress("ZK_VERIFIER_ADDR");

        console.log("Deploying Groth16Verifier...");
        console.log("  ZKVerifier:", zkVerifierAddr);

        vm.startBroadcast(deployerKey);

        // Deploy the real snarkjs-generated verifier
        Groth16Verifier groth16 = new Groth16Verifier();
        console.log("  Groth16Verifier deployed:", address(groth16));

        // Wire it into the ZKVerifier
        ZKVerifier zkVerifier = ZKVerifier(zkVerifierAddr);
        zkVerifier.setGroth16Verifier(address(groth16));
        console.log("  Wired into ZKVerifier [OK]");

        vm.stopBroadcast();

        console.log("");
        console.log("==========================================");
        console.log("Groth16Verifier:", address(groth16));
        console.log("==========================================");
        console.log("Add to frontend/.env.local:");
        console.log("  NEXT_PUBLIC_GROTH16_VERIFIER=", address(groth16));
    }
}
