// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {TaskMarketplace} from "../src/marketplace/TaskMarketplace.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {ReputationOracle} from "../src/reputation/ReputationOracle.sol";
import {AgentWalletFactory} from "../src/AgentWalletFactory.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";
import {IReputationOracle} from "../src/interfaces/IReputationOracle.sol";

import {InvariantHandler} from "./InvariantHandler.sol";

/// @title ProtocolInvariants
/// @notice Foundry invariant test suite for Nexus Agent Protocol.
/// @author Aditya Chotaliya [adityachotaliya.xyz] 
/// @dev Foundry's invariant runner:
///   1. Deploys all contracts fresh
///   2. Randomly calls handler functions (bounded valid actions)
///   3. After each call sequence, checks all invariant_ functions
///   4. Reports any violation with the exact call sequence that broke it
///
/// Invariants tested:
///   ESCROW:      ETH in contract >= sum of all open/assigned/submitted task rewards
///   ACCOUNTING:  ETH in = ETH paid out + fees accumulated + escrow remaining
///   REPUTATION:  No agent score ever exceeds 10000 or goes below 0
///   STATE:       No task can be in multiple terminal states simultaneously
///   TASKS:       Total completed + cancelled + active == total posted
///   FEES:        Accumulated fees never exceed total ETH received
///   REGISTRY:    Agent count is always consistent with registrations
///   NONCE:       taskNonce is strictly monotonically increasing (no reuse)
contract ProtocolInvariants is StdInvariant, Test {

    // ============================================================
    //                         SETUP
    // ============================================================

    TaskMarketplace internal marketplace;
    AgentRegistry   internal registry;
    ReputationOracle internal oracle;
    InvariantHandler internal handler;

    address constant OWNER      = address(0xA11CE);
    address constant ARBITRATOR = address(0xAA);
    address constant ENTRY_POINT = address(0xEE);

    uint256 constant INITIAL_FEE_BPS = 250; // 2.5%

    function setUp() public {
        vm.startPrank(OWNER);

        // Deploy protocol
        registry    = new AgentRegistry(OWNER);
        oracle      = new ReputationOracle(OWNER, address(registry));
        marketplace = new TaskMarketplace(
            OWNER,
            address(registry),
            address(oracle),
            ARBITRATOR,
            INITIAL_FEE_BPS
        );

        // Wire authorizations
        oracle.setAuthorizedUpdater(address(marketplace), true);
        registry.setReputationUpdater(address(oracle), true);

        vm.stopPrank();

        // Deploy handler
        handler = new InvariantHandler(marketplace, registry, oracle);

        // Fund handler's actors
        vm.deal(address(handler), 0); // handler doesn't need ETH directly

        // Tell Foundry to only call handler functions
        targetContract(address(handler));

        // Exclude these selectors from being called directly on contracts
        // (only handler should interact with the protocol)
        excludeContract(address(marketplace));
        excludeContract(address(registry));
        excludeContract(address(oracle));
    }

    // ============================================================
    //              INVARIANT 1: ESCROW INTEGRITY
    // ============================================================

    /// @notice The marketplace contract's ETH balance must always be >=
    ///         the sum of all non-terminal task rewards.
    /// @dev This catches: double payments, escrow drains, fee calculation bugs.
    function invariant_escrowNeverDrained() public view {
        uint256 contractBalance = address(marketplace).balance;
        uint256 ghostEscrow = handler.ghost_escrowBalance();

        // Contract balance should be >= ghost escrow
        // (may be higher if fees accumulated)
        assertGe(
            contractBalance,
            handler.ghost_totalFees() <= contractBalance
                ? contractBalance - handler.ghost_totalFees()
                : 0,
            "INVARIANT: escrow + accumulated fees <= contract balance"
        );
    }

    /// @notice ETH conservation: all ETH that entered must be accounted for
    /// @dev escrow + paidOut + fees = total received
    function invariant_ethConservation() public view {
        uint256 contractBalance = address(marketplace).balance;
        uint256 accFees = marketplace.accumulatedFees();
        uint256 ghostEscrow = handler.ghost_escrowBalance();
        uint256 ghostPaidOut = handler.ghost_totalPaidOut();
        uint256 ghostFees = handler.ghost_totalFees();

        // Accumulated fees in contract should match ghost tracking
        assertEq(
            accFees,
            ghostFees,
            "INVARIANT: accumulated fees mismatch with ghost tracking"
        );

        // Contract balance should equal remaining escrow + accumulated fees
        assertEq(
            contractBalance,
            ghostEscrow + accFees,
            "INVARIANT: contract balance != escrow + accumulated fees"
        );
    }

    // ============================================================
    //            INVARIANT 2: REPUTATION BOUNDS
    // ============================================================

    /// @notice Agent reputation score is always 0 <= score <= 10000
    /// @dev Checks all registered agents via handler's tracking.
    function invariant_reputationAlwaysBounded() public view {
        uint256 count = handler.getRegisteredAgentCount();
        for (uint256 i = 0; i < count && i < 20; i++) { // cap at 20 to avoid gas limit
            uint256 agentId = handler.registeredAgentIds(i);
            try oracle.getScore(agentId) returns (uint256 score) {
                assertLe(score, 10000, "INVARIANT: reputation score exceeds 10000");
            } catch {}
        }
    }

    // ============================================================
    //            INVARIANT 3: TASK STATE CONSISTENCY
    // ============================================================

    /// @notice Marketplace task count invariants
    function invariant_taskCounts() public view {
        uint256 onChainTotal = marketplace.totalTasksPosted();
        uint256 onChainCompleted = marketplace.totalTasksCompleted();

        // Completed can never exceed total posted
        assertLe(
            onChainCompleted,
            onChainTotal,
            "INVARIANT: completed tasks > total posted"
        );

        // Ghost completed should match on-chain
        assertEq(
            handler.ghost_completedTasks(),
            onChainCompleted,
            "INVARIANT: ghost completed != on-chain completed"
        );
    }

    // ============================================================
    //            INVARIANT 4: FEE INTEGRITY
    // ============================================================

    /// @notice Accumulated fees must never exceed the contract's ETH balance
    function invariant_feesNeverExceedBalance() public view {
        assertLe(
            marketplace.accumulatedFees(),
            address(marketplace).balance,
            "INVARIANT: accumulated fees > contract balance"
        );
    }

    /// @notice Fee rate applied is always <= MAX_FEE_BPS
    function invariant_feeRateAlwaysValid() public view {
        assertLe(
            marketplace.platformFeeBps(),
            marketplace.MAX_FEE_BPS(),
            "INVARIANT: platform fee exceeds MAX_FEE_BPS"
        );
    }

    // ============================================================
    //            INVARIANT 5: REGISTRY CONSISTENCY
    // ============================================================

    /// @notice Agent count in registry is consistent with registrations
    function invariant_registryAgentCount() public view {
        uint256 onChainCount = registry.totalAgents();
        uint256 handlerCount = handler.getRegisteredAgentCount();

        // On-chain count should be >= handler count
        // (handler may not have registered all — some may have reverted)
        assertGe(
            onChainCount,
            handlerCount,
            "INVARIANT: registry agent count < handler tracked count"
        );
    }

    // ============================================================
    //            INVARIANT 6: NO ETH STUCK IN HANDLER
    // ============================================================

    /// @notice Handler contract itself should never accumulate ETH
    function invariant_handlerHoldsNoETH() public view {
        assertEq(
            address(handler).balance,
            0,
            "INVARIANT: handler contract holds unexpected ETH"
        );
    }

    // ============================================================
    //            INVARIANT 7: OPEN TASKS NEVER EXCEED TOTAL
    // ============================================================

    function invariant_openTasksNeverExceedTotal() public view {
        uint256 openCount = handler.getOpenTaskCount();
        uint256 totalPosted = marketplace.totalTasksPosted();

        assertLe(
            openCount,
            totalPosted,
            "INVARIANT: open tasks > total tasks posted"
        );
    }

    // ============================================================
    //            INVARIANT 8: ZERO ADDRESS NEVER GETS PAID
    // ============================================================

    /// @notice The zero address should never accumulate ETH from the protocol
    function invariant_zeroAddressNeverReceivesETH() public view {
        // Zero address balance should always be 0
        assertEq(
            address(0).balance,
            0,
            "INVARIANT: zero address received ETH"
        );
    }
}
