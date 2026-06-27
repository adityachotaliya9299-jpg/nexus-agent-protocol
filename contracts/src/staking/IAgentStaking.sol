// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAgentStaking
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Interface for the Nexus Agent Staking system.
///
/// @dev Staking model:
///
///   Agents put ETH at risk when accepting tasks.
///   Higher effective stake = higher trust = lower required stake per task.
///
///   Stake flow:
///     stake(agentId)        → ETH locked in contract
///     acceptTask(taskId)    → portion locked for task duration
///     completeTask(taskId)  → stake released
///     slashStake(agentId)   → portion burned/sent to treasury on bad behavior
///     unstake(agentId)      → ETH returned after unbonding delay
///
///   Effective stake (for bid eligibility):
///     effectiveStake = rawStake * reputationMultiplier
///     reputationMultiplier = reputationScore / 5000
///     (agents at 50% rep → 1x, at 100% rep → 2x multiplier)
///
///   Delegated staking:
///     Third parties can stake on behalf of agents.
///     If agent is slashed, delegator loses their stake too.
interface IAgentStaking {

    // ============================================================
    //                         STRUCTS
    // ============================================================

    struct StakeInfo {
        uint256 agentId;
        uint256 totalStaked;       // Raw ETH staked (own + delegated)
        uint256 ownStake;          // ETH staked by agent owner
        uint256 delegatedStake;    // ETH staked by third parties
        uint256 lockedStake;       // Portion locked for active tasks
        uint256 slashCount;        // Number of times slashed
        uint256 totalSlashed;      // Total ETH slashed historically
        uint256 lastStakedAt;
        uint256 unstakeRequestedAt; // Non-zero if unstake pending
        uint256 unstakeAmount;      // Amount requested for unstake
    }

    struct DelegatorInfo {
        address delegator;
        uint256 agentId;
        uint256 amount;
        uint256 stakedAt;
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event Staked(uint256 indexed agentId, address indexed staker, uint256 amount, bool isDelegated);
    event UnstakeRequested(uint256 indexed agentId, address indexed requester, uint256 amount);
    event Unstaked(uint256 indexed agentId, address indexed recipient, uint256 amount);
    event StakeLocked(uint256 indexed agentId, bytes32 indexed taskId, uint256 amount);
    event StakeUnlocked(uint256 indexed agentId, bytes32 indexed taskId, uint256 amount);
    event Slashed(uint256 indexed agentId, uint256 amount, address indexed recipient, string reason);
    event MinStakeUpdated(uint256 newMinStake);
    event SlashRateUpdated(uint256 newSlashBps);
    event UnbondingDelayUpdated(uint256 newDelay);

    // ============================================================
    //                         ERRORS
    // ============================================================

    error AgentNotFound(uint256 agentId);
    error NotAgentOwner(uint256 agentId);
    error NotAuthorized();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientStake(uint256 agentId, uint256 required, uint256 actual);
    error StakeIsLocked(uint256 agentId, uint256 lockedAmount);
    error UnstakePending(uint256 agentId);
    error UnbondingNotComplete(uint256 agentId, uint256 unlocksAt);
    error NothingToUnstake(uint256 agentId);
    error InvalidSlashRate();
    error TaskAlreadyLocked(bytes32 taskId);
    error TaskNotLocked(bytes32 taskId);
    error NoDelegationFound(address delegator, uint256 agentId);

    // ============================================================
    //                     CORE FUNCTIONS
    // ============================================================

    /// @notice Stake ETH for your own agent
    function stake(uint256 agentId) external payable;

    /// @notice Delegate stake to another agent (third-party staking)
    function delegateStake(uint256 agentId) external payable;

    /// @notice Request unstake — starts unbonding delay
    function requestUnstake(uint256 agentId, uint256 amount) external;

    /// @notice Finalize unstake after unbonding delay
    function unstake(uint256 agentId) external;

    /// @notice Remove delegated stake (subject to unbonding delay)
    function removeDelegatedStake(uint256 agentId) external;

    // ============================================================
    //                   PROTOCOL FUNCTIONS
    // ============================================================

    /// @notice Lock stake for a specific task (called by marketplace)
    function lockStakeForTask(uint256 agentId, bytes32 taskId, uint256 amount) external;

    /// @notice Unlock stake after task completion (called by marketplace)
    function unlockStakeForTask(uint256 agentId, bytes32 taskId) external;

    /// @notice Slash an agent's stake (called by governance or arbitrator)
    function slashStake(uint256 agentId, uint256 slashBps, address recipient, string calldata reason) external;

    // ============================================================
    //                     VIEW FUNCTIONS
    // ============================================================

    function getStake(uint256 agentId) external view returns (StakeInfo memory);
    function getEffectiveStake(uint256 agentId) external view returns (uint256);
    function getDelegatorStake(address delegator, uint256 agentId) external view returns (uint256);
    function isEligibleToBid(uint256 agentId, uint256 taskMinStake) external view returns (bool);
    function minStakeToRegister() external view returns (uint256);
    function slashRateBps() external view returns (uint256);
    function unbondingDelay() external view returns (uint256);
}
