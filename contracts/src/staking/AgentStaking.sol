// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentStaking} from "./IAgentStaking.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";
import {IReputationOracle} from "../interfaces/IReputationOracle.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title AgentStaking
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Agent staking with delegation, task locking, slashing, and unbonding.
///
/// @dev Key design decisions:
///
///   EFFECTIVE STAKE = rawStake × reputationMultiplier
///   Reputation multiplier = score / 5000
///   At score 5000 (50%) → 1.0x | At score 10000 (100%) → 2.0x
///   This means high-rep agents need less raw ETH to qualify for the same tasks.
///
///   UNBONDING DELAY (default: 7 days)
///   Prevents stake withdrawal during active disputes.
///   Lockedstake cannot be unstaked at all until unlocked by marketplace.
///
///   SLASHING
///   slashBps (basis points) of current stake taken on bad behavior.
///   Slashed ETH goes to treasury (or arbitrator for dispute-triggered slashes).
///   Delegators lose proportionally if agent is slashed.
///
///   TASK LOCKING
///   When marketplace assigns a task, it locks a portion of the agent's stake.
///   If agent disappears/refuses, arbitrator can slash the locked amount.
///   On completion or dispute resolution, marketplace unlocks the stake.
contract AgentStaking is IAgentStaking, ReentrancyGuard {

    // ============================================================
    //                       CONSTANTS
    // ============================================================

    uint256 public constant MAX_SLASH_BPS     = 5000;  // Max 50% slash per event
    uint256 public constant MIN_UNBONDING     = 1 days;
    uint256 public constant MAX_UNBONDING     = 30 days;
    uint256 public constant REPUTATION_SCALE  = 5000;  // score/5000 = multiplier

    // ============================================================
    //                         STORAGE
    // ============================================================

    address public immutable protocolOwner;
    address public immutable registry;
    address public immutable reputationOracle;

    /// @notice Addresses authorized to lock/unlock/slash (marketplace, arbitrator)
    mapping(address => bool) public isAuthorized;

    /// @notice agentId => StakeInfo
    mapping(uint256 => StakeInfo) private _stakes;

    /// @notice delegator => agentId => amount
    mapping(address => mapping(uint256 => uint256)) private _delegatorStakes;

    /// @notice agentId => list of delegators
    mapping(uint256 => address[]) private _agentDelegators;

    /// @notice taskId => agentId (for locked stake tracking)
    mapping(bytes32 => uint256) private _taskToAgent;

    /// @notice taskId => locked amount
    mapping(bytes32 => uint256) private _taskLockedAmount;

    /// @notice Protocol parameters
    uint256 public override minStakeToRegister; // 0 by default (optional)
    uint256 public override slashRateBps;       // default: 1000 = 10%
    uint256 public override unbondingDelay;     // default: 7 days

    /// @notice Treasury address for slashed funds
    address public treasury;

    // ============================================================
    //                       MODIFIERS
    // ============================================================

    modifier onlyOwner() {
        if (msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    modifier onlyAuthorized() {
        if (!isAuthorized[msg.sender] && msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    modifier agentExists(uint256 agentId) {
        _requireAgentExists(agentId);
        _;
    }

    // ============================================================
    //                       CONSTRUCTOR
    // ============================================================

    constructor(
        address _protocolOwner,
        address _registry,
        address _reputationOracle,
        address _treasury
    ) {
        if (_protocolOwner == address(0) || _registry == address(0) ||
            _reputationOracle == address(0) || _treasury == address(0)) {
            revert ZeroAddress();
        }

        protocolOwner    = _protocolOwner;
        registry         = _registry;
        reputationOracle = _reputationOracle;
        treasury         = _treasury;

        slashRateBps  = 1000;   // 10% default slash
        unbondingDelay = 7 days; // 7-day unbonding
    }

    // ============================================================
    //                     STAKE (OWN)
    // ============================================================

    /// @notice Agent owner stakes ETH for their agent
    function stake(uint256 agentId) external payable override nonReentrant agentExists(agentId) {
        if (msg.value == 0) revert ZeroAmount();

        // Verify caller is the agent owner
        IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(agentId);
        if (profile.owner != msg.sender) revert NotAgentOwner(agentId);

        StakeInfo storage s = _stakes[agentId];
        s.agentId     = agentId;
        s.totalStaked += msg.value;
        s.ownStake    += msg.value;
        s.lastStakedAt = block.timestamp;

        emit Staked(agentId, msg.sender, msg.value, false);
    }

    // ============================================================
    //                   DELEGATED STAKING
    // ============================================================

    /// @notice Anyone can stake ETH on behalf of an agent
    /// @dev Delegators share in slashing — if agent misbehaves, delegators lose too
    function delegateStake(uint256 agentId) external payable override nonReentrant agentExists(agentId) {
        if (msg.value == 0) revert ZeroAmount();

        // Track delegator
        if (_delegatorStakes[msg.sender][agentId] == 0) {
            _agentDelegators[agentId].push(msg.sender);
        }
        _delegatorStakes[msg.sender][agentId] += msg.value;

        StakeInfo storage s = _stakes[agentId];
        s.agentId         = agentId;
        s.totalStaked     += msg.value;
        s.delegatedStake  += msg.value;
        s.lastStakedAt    = block.timestamp;

        emit Staked(agentId, msg.sender, msg.value, true);
    }

    // ============================================================
    //                       UNSTAKING
    // ============================================================

    /// @notice Agent owner requests unstake — starts unbonding delay
    function requestUnstake(uint256 agentId, uint256 amount) external override nonReentrant agentExists(agentId) {
        IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(agentId);
        if (profile.owner != msg.sender) revert NotAgentOwner(agentId);

        StakeInfo storage s = _stakes[agentId];
        if (amount == 0) revert ZeroAmount();
        if (s.unstakeRequestedAt != 0) revert UnstakePending(agentId);

        // Cannot unstake locked stake
        uint256 available = s.ownStake > s.lockedStake ? s.ownStake - s.lockedStake : 0;
        if (amount > available) revert InsufficientStake(agentId, amount, available);

        s.unstakeRequestedAt = block.timestamp;
        s.unstakeAmount      = amount;

        emit UnstakeRequested(agentId, msg.sender, amount);
    }

    /// @notice Finalize unstake after unbonding delay passes
    function unstake(uint256 agentId) external override nonReentrant agentExists(agentId) {
        IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(agentId);
        if (profile.owner != msg.sender) revert NotAgentOwner(agentId);

        StakeInfo storage s = _stakes[agentId];
        if (s.unstakeRequestedAt == 0) revert NothingToUnstake(agentId);

        uint256 unlocksAt = s.unstakeRequestedAt + unbondingDelay;
        if (block.timestamp < unlocksAt) revert UnbondingNotComplete(agentId, unlocksAt);

        uint256 amount = s.unstakeAmount;
        s.totalStaked -= amount;
        s.ownStake    -= amount;
        s.unstakeRequestedAt = 0;
        s.unstakeAmount      = 0;

        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "Transfer failed");

        emit Unstaked(agentId, msg.sender, amount);
    }

    /// @notice Delegator removes their stake (subject to unbonding)
    function removeDelegatedStake(uint256 agentId) external override nonReentrant agentExists(agentId) {
        uint256 amount = _delegatorStakes[msg.sender][agentId];
        if (amount == 0) revert NoDelegationFound(msg.sender, agentId);

        
        StakeInfo storage s = _stakes[agentId];
        if (s.lockedStake > 0) revert StakeIsLocked(agentId, s.lockedStake);

        _delegatorStakes[msg.sender][agentId] = 0;
        s.totalStaked    -= amount;
        s.delegatedStake -= amount;

        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "Transfer failed");

        emit Unstaked(agentId, msg.sender, amount);
    }

    // ============================================================
    //                    TASK LOCKING
    // ============================================================

    /// @notice Lock stake when agent is assigned a task (called by marketplace)
    function lockStakeForTask(uint256 agentId, bytes32 taskId, uint256 amount)
        external override onlyAuthorized agentExists(agentId)
    {
        if (_taskLockedAmount[taskId] != 0) revert TaskAlreadyLocked(taskId);
        if (amount == 0) return; // No lock required for this task

        StakeInfo storage s = _stakes[agentId];
        uint256 available = s.totalStaked - s.lockedStake;
        if (available < amount) revert InsufficientStake(agentId, amount, available);

        s.lockedStake += amount;
        _taskLockedAmount[taskId] = amount;
        _taskToAgent[taskId] = agentId;

        emit StakeLocked(agentId, taskId, amount);
    }

    /// @notice Unlock stake after task completes or cancels (called by marketplace)
    function unlockStakeForTask(uint256 agentId, bytes32 taskId)
        external override onlyAuthorized
    {
        uint256 amount = _taskLockedAmount[taskId];
        if (amount == 0) return; // Nothing locked, no-op

        StakeInfo storage s = _stakes[agentId];
        s.lockedStake = s.lockedStake >= amount ? s.lockedStake - amount : 0;

        delete _taskLockedAmount[taskId];
        delete _taskToAgent[taskId];

        emit StakeUnlocked(agentId, taskId, amount);
    }

    // ============================================================
    //                       SLASHING
    // ============================================================

    /// @notice Slash an agent's stake (arbitrator or governance)
    /// @param agentId Agent to slash
    /// @param slashBps Percentage of total stake to slash (basis points)
    /// @param recipient Where slashed ETH goes (treasury or arbitrator)
    /// @param reason Human-readable slash reason
    function slashStake(
        uint256 agentId,
        uint256 slashBps,
        address recipient,
        string calldata reason
    ) external override onlyAuthorized nonReentrant agentExists(agentId) {
        if (slashBps == 0 || slashBps > MAX_SLASH_BPS) revert InvalidSlashRate();
        if (recipient == address(0)) revert ZeroAddress();

        StakeInfo storage s = _stakes[agentId];
        if (s.totalStaked == 0) return; // Nothing to slash

        uint256 slashAmount = (s.totalStaked * slashBps) / 10000;

        // Slash proportionally from own + delegated stake
        uint256 ownSlash = s.totalStaked > 0
            ? (slashAmount * s.ownStake) / s.totalStaked : 0;
        uint256 delegatedSlash = slashAmount - ownSlash;

        s.totalStaked    -= slashAmount;
        s.ownStake       -= ownSlash;
        s.delegatedStake = s.delegatedStake >= delegatedSlash
            ? s.delegatedStake - delegatedSlash : 0;
        s.lockedStake    = s.lockedStake >= slashAmount
            ? s.lockedStake - slashAmount : 0;
        s.slashCount++;
        s.totalSlashed   += slashAmount;

        // Slash delegators proportionally
        _slashDelegators(agentId, slashBps);

        // Send slashed ETH to recipient
        (bool ok,) = payable(recipient).call{value: slashAmount}("");
        require(ok, "Slash transfer failed");

        emit Slashed(agentId, slashAmount, recipient, reason);
    }

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    function getStake(uint256 agentId) external view override returns (StakeInfo memory) {
        return _stakes[agentId];
    }

    /// @notice Effective stake = rawStake × (reputationScore / REPUTATION_SCALE)
    function getEffectiveStake(uint256 agentId) external view override returns (uint256) {
        StakeInfo storage s = _stakes[agentId];
        if (s.totalStaked == 0) return 0;

        uint256 score = _getReputationScore(agentId);
        // effectiveStake = totalStaked * score / REPUTATION_SCALE
        // At 5000 rep → 1x, at 10000 rep → 2x, at 2500 rep → 0.5x
        return (s.totalStaked * score) / REPUTATION_SCALE;
    }

    function getDelegatorStake(address delegator, uint256 agentId)
        external view override returns (uint256)
    {
        return _delegatorStakes[delegator][agentId];
    }

    function isEligibleToBid(uint256 agentId, uint256 taskMinStake)
        external view override returns (bool)
    {
        if (taskMinStake == 0) return true; // No stake required
        StakeInfo storage s = _stakes[agentId];
        uint256 available = s.totalStaked - s.lockedStake;
        uint256 score = _getReputationScore(agentId);
        uint256 effective = (available * score) / REPUTATION_SCALE;
        return effective >= taskMinStake;
    }

    // ============================================================
    //                      ADMIN FUNCTIONS
    // ============================================================

    function setAuthorized(address addr, bool authorized) external onlyOwner {
        if (addr == address(0)) revert ZeroAddress();
        isAuthorized[addr] = authorized;
    }

    function setSlashRate(uint256 newSlashBps) external onlyOwner {
        if (newSlashBps > MAX_SLASH_BPS) revert InvalidSlashRate();
        slashRateBps = newSlashBps;
        emit SlashRateUpdated(newSlashBps);
    }

    function setUnbondingDelay(uint256 newDelay) external onlyOwner {
        if (newDelay < MIN_UNBONDING || newDelay > MAX_UNBONDING) revert InvalidSlashRate();
        unbondingDelay = newDelay;
        emit UnbondingDelayUpdated(newDelay);
    }

    function setMinStake(uint256 newMin) external onlyOwner {
        minStakeToRegister = newMin;
        emit MinStakeUpdated(newMin);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        treasury = newTreasury;
    }

    // ============================================================
    //                     INTERNAL HELPERS
    // ============================================================

    function _requireAgentExists(uint256 agentId) internal view {
        try IAgentRegistry(registry).getAgent(agentId) returns (IAgentRegistry.AgentProfile memory) {}
        catch { revert AgentNotFound(agentId); }
    }

    function _getReputationScore(uint256 agentId) internal view returns (uint256) {
        try IReputationOracle(reputationOracle).getScore(agentId) returns (uint256 score) {
            return score == 0 ? REPUTATION_SCALE : score; // floor at 1x
        } catch {
            return REPUTATION_SCALE; // default to 1x if oracle unavailable
        }
    }

    function _slashDelegators(uint256 agentId, uint256 slashBps) internal {
        address[] storage delegators = _agentDelegators[agentId];
        for (uint256 i = 0; i < delegators.length; i++) {
            address delegator = delegators[i];
            uint256 delegatorStake = _delegatorStakes[delegator][agentId];
            if (delegatorStake == 0) continue;
            uint256 slashAmount = (delegatorStake * slashBps) / 10000;
            _delegatorStakes[delegator][agentId] -= slashAmount;
        }
    }
}
