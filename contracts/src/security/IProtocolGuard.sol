// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProtocolGuard
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Interface for the Nexus protocol circuit breaker and invariant monitor.
///
/// @dev On-chain security layer that:
///
///   CIRCUIT BREAKER:
///     - Owner or guardians can pause individual contracts or the entire protocol
///     - Pause is time-limited (max 7 days) to prevent permanent lockout
///     - Unpause requires owner or quorum of guardians
///     - Contracts check isPaused() before executing sensitive operations
///
///   INVARIANT MONITOR:
///     - Registers invariant checks as function selectors + target contracts
///     - Anyone can trigger checkInvariant(invariantId)
///     - If check fails → emits InvariantViolated, optionally auto-pauses
///     - Foundry-style invariants translated to on-chain monitors
///
///   GUARDIAN SYSTEM:
///     - Multiple guardians can pause (any single guardian can pause)
///     - Unpausing requires owner or 2/3 of guardians
///     - Guardians are multisig signers or trusted addresses
///
///   RATE LIMITER:
///     - Tracks ETH outflow per time window
///     - Auto-pauses if outflow exceeds threshold (e.g. > 10 ETH in 1 hour)
///     - Protects against drain attacks even if a contract is compromised
interface IProtocolGuard {

    // ============================================================
    //                         ENUMS
    // ============================================================

    enum PauseScope { NONE, PARTIAL, FULL }

    // ============================================================
    //                         STRUCTS
    // ============================================================

    struct ContractStatus {
        address  target;
        bool     isPaused;
        uint256  pausedAt;
        uint256  pauseExpiresAt;
        address  pausedBy;
        string   pauseReason;
        uint256  totalPauses;
    }

    struct Invariant {
        bytes32  invariantId;
        string   description;
        address  target;         // Contract to check
        bytes4   selector;       // Function selector of the check
        bool     autoPauseOnFail;
        bool     isActive;
        uint256  lastCheckedAt;
        uint256  violationCount;
    }

    struct RateLimit {
        uint256 windowSeconds;   // Time window (e.g. 3600 = 1 hour)
        uint256 maxOutflowWei;   // Max ETH out in window
        uint256 currentOutflow;  // Current window outflow
        uint256 windowStartedAt;
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event ContractPaused(address indexed target, address indexed by, string reason, uint256 expiresAt);
    event ContractUnpaused(address indexed target, address indexed by);
    event ProtocolPaused(address indexed by, string reason);
    event ProtocolUnpaused(address indexed by);
    event InvariantRegistered(bytes32 indexed invariantId, address target, string description);
    event InvariantViolated(bytes32 indexed invariantId, address target, uint256 timestamp);
    event InvariantCheckPassed(bytes32 indexed invariantId);
    event GuardianAdded(address indexed guardian);
    event GuardianRemoved(address indexed guardian);
    event RateLimitTriggered(address indexed target, uint256 outflow, uint256 limit);

    // ============================================================
    //                         ERRORS
    // ============================================================

    error NotAuthorized();
    error ZeroAddress();
    error AlreadyPaused(address target);
    error NotPaused(address target);
    error PauseTooLong(uint256 duration, uint256 maxDuration);
    error InvariantNotFound(bytes32 invariantId);
    error RateLimitExceeded(uint256 outflow, uint256 limit);
    error ProtocolIsPaused();

    // ============================================================
    //                     CIRCUIT BREAKER
    // ============================================================

    function pause(address target, string calldata reason, uint256 duration) external;
    function unpause(address target) external;
    function pauseAll(string calldata reason) external;
    function unpauseAll() external;
    function isPaused(address target) external view returns (bool);
    function getContractStatus(address target) external view returns (ContractStatus memory);

    // ============================================================
    //                   INVARIANT MONITOR
    // ============================================================

    function registerInvariant(
        string calldata description,
        address target,
        bytes4 selector,
        bool autoPauseOnFail
    ) external returns (bytes32 invariantId);

    function checkInvariant(bytes32 invariantId) external returns (bool passed);
    function checkAllInvariants() external returns (uint256 passed, uint256 failed);
    function getInvariant(bytes32 invariantId) external view returns (Invariant memory);
    function totalInvariants() external view returns (uint256);

    // ============================================================
    //                     GUARDIAN SYSTEM
    // ============================================================

    function addGuardian(address guardian) external;
    function removeGuardian(address guardian) external;
    function isGuardian(address addr) external view returns (bool);
    function guardianCount() external view returns (uint256);

    // ============================================================
    //                      RATE LIMITER
    // ============================================================

    function recordOutflow(address target, uint256 amount) external;
    function getRateLimit() external view returns (RateLimit memory);
    function setRateLimit(uint256 windowSeconds, uint256 maxOutflowWei) external;
}
