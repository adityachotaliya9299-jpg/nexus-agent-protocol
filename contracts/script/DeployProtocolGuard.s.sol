// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ProtocolGuard}   from "../src/security/ProtocolGuard.sol";

/// @title DeployProtocolGuard
/// @notice Deploys the ProtocolGuard security contract and registers core invariants.
///
/// Usage:
///   forge script script/DeployProtocolGuard.s.sol \
///     --rpc-url $SEPOLIA_RPC_URL \
///     --broadcast \
///     --verify \
///     --etherscan-api-key $ETHERSCAN_API_KEY \
///     -vvvv
contract DeployProtocolGuard is Script {
    function run() external {
        uint256 deployerKey     = vm.envUint("PRIVATE_KEY");
        address deployer        = vm.addr(deployerKey);
        address taskMarketplace = vm.envAddress("TASK_MARKETPLACE_ADDR");
        address agentStaking    = vm.envAddress("AGENT_STAKING_ADDR");

        console.log("==========================================");
        console.log("Deploying ProtocolGuard");
        console.log("==========================================");
        console.log("Deployer:       ", deployer);
        console.log("TaskMarketplace:", taskMarketplace);
        console.log("AgentStaking:   ", agentStaking);

        vm.startBroadcast(deployerKey);

        ProtocolGuard guard = new ProtocolGuard(deployer);

        // Add deployer as guardian (can be replaced with multisig)
        guard.addGuardian(deployer);

        // Set rate limit: 5 ETH per hour (conservative for testnet)
        guard.setRateLimit(3600, 5 ether);

        try guard.registerInvariant(
            "Marketplace fee rate <= MAX_FEE_BPS",
            taskMarketplace,
            bytes4(keccak256("invariant_feeRateValid()")),
            true // auto-pause on violation
        ) returns (bytes32 id) {
            console.log("  invariant_feeRateValid registered:", vm.toString(id));
        } catch {
            console.log("  Note: invariant_feeRateValid() not found on marketplace");
            console.log("  Add it to TaskMarketplace or register manually later");
        }

        vm.stopBroadcast();

        console.log("");
        console.log("==========================================");
        console.log("ProtocolGuard deployed:", address(guard));
        console.log("==========================================");
        console.log("Add to .env:");
        console.log("  PROTOCOL_GUARD_ADDR=", address(guard));
        console.log("");
        console.log("Integration (add to each Nexus contract):");
        console.log("  import {IProtocolGuard} from './security/IProtocolGuard.sol';");
        console.log("  modifier whenNotPaused() {");
        console.log("    if (IProtocolGuard(GUARD_ADDR).isPaused(address(this))) revert ProtocolIsPaused();");
        console.log("    _;");
        console.log("  }");
        console.log("");
        console.log("Register more invariants:");
        console.log("  cast send", address(guard), "'registerInvariant(string,address,bytes4,bool)'");
        console.log("    'description' <target> <selector> true");
        console.log("    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY");
        console.log("==========================================");
    }
}
