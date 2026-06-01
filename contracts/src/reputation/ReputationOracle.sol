// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IReputationOracle} from "../interfaces/IReputationOracle.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";

/// @title ReputationOracle
/// @author Aditya Chotaliya [adityachotaliya.vercel.app]
/// @notice On-chain reputation system for autonomous AI agents
///
/// @dev Score Model (basis points, 0–10000, starts at 5000):
///
///   INCREASES:
///     Task completed     → +TASK_COMPLETE_WEIGHT  (default: +50 bp)
///     Positive rating    → +POSITIVE_RATING_WEIGHT (default: +30 bp)
///     Dispute won        → +DISPUTE_WON_WEIGHT     (default: +100 bp)
///
///   DECREASES:
///     Task failed        → -TASK_FAIL_WEIGHT       (default: -80 bp)
///     Negative rating    → -NEGATIVE_RATING_WEIGHT (default: -40 bp)
///     Dispute lost       → -DISPUTE_LOST_WEIGHT    (default: -150 bp)
///     Inactivity penalty → -INACTIVITY_WEIGHT      (default: -20 bp)
///
///   SLASH: immediate large penalty, sets isSlashed=true
///     Slashed agents cannot accept new tasks until rehabilitated
///
/// Security:
///   - Only authorized updaters (TaskMarketplace, AVS) can submit updates
///   - Protocol owner can slash/rehabilitate and set weights
///   - All events stored on-chain for full audit trail
///   - Score always clamped to [SCORE_FLOOR, SCORE_CEILING]
///
/// Phase 4 hook:
///   Chainlink Functions will call updateReputation() based on
///   off-chain signals (response time, model accuracy, etc.)

contract ReputationOracle is IReputationOracle {
    // ============================================================
    //                       CONSTANTS
    // ============================================================

    uint256 public constant SCORE_CEILING = 10000; // 100%
    uint256 public constant SCORE_FLOOR   = 0;
    uint256 public constant INITIAL_SCORE = 5000;  // Start at 50%
    uint256 public constant MAX_SLASH_PENALTY = 5000; // Max 50% in one slash

    // ============================================================
    //                    DEFAULT WEIGHTS (bp)
    // ============================================================

    uint256 public taskCompleteWeight    = 50;
    uint256 public taskFailWeight        = 80;
    uint256 public positiveRatingWeight  = 30;
    uint256 public negativeRatingWeight  = 40;
    uint256 public disputeWonWeight      = 100;
    uint256 public disputeLostWeight     = 150;
    uint256 public inactivityWeight      = 20;

    // ============================================================
    //                         STORAGE
    // ============================================================

    /// @notice Protocol owner — can set weights, slash, authorize updaters
    address public immutable protocolOwner;

    /// @notice AgentRegistry — used to verify agents exist
    address public immutable registry;

    /// @notice agentId => full reputation state
    mapping(uint256 => ReputationState) private _reputations;

    /// @notice agentId => ordered list of reputation events
    mapping(uint256 => ReputationEvent[]) private _eventHistory;

    /// @notice Addresses authorized to submit reputation updates
    mapping(address => bool) private _authorizedUpdaters;

    // ============================================================
    //                       MODIFIERS
    // ============================================================

    modifier onlyProtocolOwner() {
        if (msg.sender != protocolOwner) revert NotProtocolOwner();
        _;
    }

    modifier onlyAuthorizedUpdater() {
        if (!_authorizedUpdaters[msg.sender]) revert NotAuthorizedUpdater(msg.sender);
        _;
    }

    modifier agentInitialized(uint256 agentId) {
    if (_reputations[agentId].registeredAt == 0) revert AgentNotInitialized(agentId);
    _;
    }

    modifier agentNotSlashed(uint256 agentId) {
        if (_reputations[agentId].isSlashed) revert AgentIsSlashed(agentId);
        _;
    }

    // ============================================================
    //                       CONSTRUCTOR
    // ============================================================

    constructor(address _protocolOwner, address _registry) {
        if (_protocolOwner == address(0) || _registry == address(0)) revert ZeroAddress();
        protocolOwner = _protocolOwner;
        registry = _registry;

        // Protocol owner is an authorized updater by default
        _authorizedUpdaters[_protocolOwner] = true;
        emit AuthorizedUpdaterSet(_protocolOwner, true);
    }

    // ============================================================
    //                    INITIALIZATION
    // ============================================================

    /// @notice Initialize reputation tracking for a newly registered agent
    /// @dev Called by AgentRegistry or protocol owner after agent registration
    ///      Can also be called by authorized updaters (marketplace on first task)
    function initializeAgent(uint256 agentId) external override {
        // Allow protocol owner OR authorized updaters to initialize
        require(
            msg.sender == protocolOwner || _authorizedUpdaters[msg.sender],
            "Not authorized to initialize"
        );

        if (_reputations[agentId].registeredAt != 0) revert AlreadyInitialized(agentId);

        // Verify the agent exists in the registry
        require(
            IAgentRegistry(registry).getAgent(agentId).agentId == agentId,
            "Agent not found in registry"
        );

        _reputations[agentId] = ReputationState({
            agentId: agentId,
            score: INITIAL_SCORE,
            totalUpdates: 0,
            tasksCompleted: 0,
            tasksFailed: 0,
            positiveRatings: 0,
            negativeRatings: 0,
            disputesWon: 0,
            disputesLost: 0,
            lastUpdateAt: block.timestamp,
            registeredAt: block.timestamp,
            isSlashed: false
        });

        emit ReputationInitialized(agentId, INITIAL_SCORE);
    }

    // ============================================================
    //                    REPUTATION UPDATES
    // ============================================================

    /// @notice Submit a reputation event for an agent
    /// @dev Only authorized updaters (marketplace, AVS) can call this
    function updateReputation(
        uint256 agentId,
        UpdateReason reason,
        bytes32 taskId
    ) external override onlyAuthorizedUpdater agentInitialized(agentId) agentNotSlashed(agentId) {
        ReputationState storage rep = _reputations[agentId];
        uint256 oldScore = rep.score;
        uint256 newScore = _computeNewScore(oldScore, reason, rep);

        // Update stats counters
        _updateCounters(rep, reason);

        // Apply new score (clamped)
        rep.score = newScore;
        rep.totalUpdates++;
        rep.lastUpdateAt = block.timestamp;

        // Record event in history
        _eventHistory[agentId].push(ReputationEvent({
            agentId: agentId,
            oldScore: oldScore,
            newScore: newScore,
            reason: reason,
            updatedBy: msg.sender,
            timestamp: block.timestamp,
            taskId: taskId
        }));

        // Sync back to AgentRegistry
        _syncToRegistry(agentId, newScore, rep);

        emit ReputationUpdated(agentId, oldScore, newScore, reason, msg.sender, taskId);
    }

    // ============================================================
    //                       SLASH / REHAB
    // ============================================================

    /// @notice Slash an agent — large penalty + flag
    /// @dev Used for severe violations: fraud, spam, malicious behavior
    function slashAgent(
        uint256 agentId,
        uint256 penaltyPoints,
        string calldata reason
    ) external override onlyProtocolOwner agentInitialized(agentId) {
        if (penaltyPoints == 0 || penaltyPoints > MAX_SLASH_PENALTY) {
            revert InvalidPenalty(penaltyPoints);
        }

        ReputationState storage rep = _reputations[agentId];
        uint256 oldScore = rep.score;

        // Apply penalty, floor at SCORE_FLOOR
        uint256 newScore = oldScore > penaltyPoints
            ? oldScore - penaltyPoints
            : SCORE_FLOOR;

        rep.score = newScore;
        rep.isSlashed = true;
        rep.totalUpdates++;
        rep.lastUpdateAt = block.timestamp;

        _eventHistory[agentId].push(ReputationEvent({
            agentId: agentId,
            oldScore: oldScore,
            newScore: newScore,
            reason: UpdateReason.MANUAL_OVERRIDE,
            updatedBy: msg.sender,
            timestamp: block.timestamp,
            taskId: bytes32(0)
        }));

        emit AgentSlashed(agentId, penaltyPoints, reason);
        emit ReputationUpdated(agentId, oldScore, newScore, UpdateReason.MANUAL_OVERRIDE, msg.sender, bytes32(0));
    }

    /// @notice Rehabilitate a slashed agent after review
    function rehabilitateAgent(uint256 agentId)
        external
        override
        onlyProtocolOwner
        agentInitialized(agentId)
    {
        require(_reputations[agentId].isSlashed, "Agent is not slashed");
        _reputations[agentId].isSlashed = false;
        emit AgentRehabilitiated(agentId);
    }

    // ============================================================
    //                    WEIGHT MANAGEMENT
    // ============================================================

    /// @notice Update scoring weights — protocol governance
    function setWeights(
        uint256 _taskComplete,
        uint256 _taskFail,
        uint256 _positiveRating,
        uint256 _negativeRating,
        uint256 _disputeWon,
        uint256 _disputeLost,
        uint256 _inactivity
    ) external onlyProtocolOwner {
        taskCompleteWeight   = _taskComplete;
        taskFailWeight       = _taskFail;
        positiveRatingWeight = _positiveRating;
        negativeRatingWeight = _negativeRating;
        disputeWonWeight     = _disputeWon;
        disputeLostWeight    = _disputeLost;
        inactivityWeight     = _inactivity;
    }

    // ============================================================
    //                    AUTHORIZED UPDATERS
    // ============================================================

    function setAuthorizedUpdater(address updater, bool authorized)
        external
        override
        onlyProtocolOwner
    {
        if (updater == address(0)) revert ZeroAddress();
        _authorizedUpdaters[updater] = authorized;
        emit AuthorizedUpdaterSet(updater, authorized);
    }

    // ============================================================
    //                     INTERNAL HELPERS
    // ============================================================

    /// @notice Compute new score based on reason and weights
    function _computeNewScore(
        uint256 currentScore,
        UpdateReason reason,
        ReputationState storage /*rep*/
    ) internal view returns (uint256) {
        uint256 newScore = currentScore;

        if (reason == UpdateReason.TASK_COMPLETED) {
            newScore = _add(currentScore, taskCompleteWeight);
        } else if (reason == UpdateReason.TASK_FAILED) {
            newScore = _sub(currentScore, taskFailWeight);
        } else if (reason == UpdateReason.POSITIVE_RATING) {
            newScore = _add(currentScore, positiveRatingWeight);
        } else if (reason == UpdateReason.NEGATIVE_RATING) {
            newScore = _sub(currentScore, negativeRatingWeight);
        } else if (reason == UpdateReason.DISPUTE_WON) {
            newScore = _add(currentScore, disputeWonWeight);
        } else if (reason == UpdateReason.DISPUTE_LOST) {
            newScore = _sub(currentScore, disputeLostWeight);
        } else if (reason == UpdateReason.INACTIVITY_PENALTY) {
            newScore = _sub(currentScore, inactivityWeight);
        }
        // MANUAL_OVERRIDE: no auto-compute, handled separately in slashAgent

        return newScore;
    }

    /// @notice Update stat counters based on reason
    function _updateCounters(ReputationState storage rep, UpdateReason reason) internal {
        if (reason == UpdateReason.TASK_COMPLETED)   { rep.tasksCompleted++; }
        else if (reason == UpdateReason.TASK_FAILED) { rep.tasksFailed++; }
        else if (reason == UpdateReason.POSITIVE_RATING) { rep.positiveRatings++; }
        else if (reason == UpdateReason.NEGATIVE_RATING) { rep.negativeRatings++; }
        else if (reason == UpdateReason.DISPUTE_WON)  { rep.disputesWon++; }
        else if (reason == UpdateReason.DISPUTE_LOST) { rep.disputesLost++; }
    }

    /// @notice Sync reputation score back to AgentRegistry
    function _syncToRegistry(uint256 agentId, uint256 newScore, ReputationState storage rep) internal {
    // Registry sync is handled externally — oracle is source of truth for scores.
    // In Phase 3, TaskMarketplace will call registry.updateReputation() directly
    // since it is an authorized updater with full task + earnings context.
    // Suppress unused variable warning:
    (agentId, newScore, rep);
    }

    /// @notice Add with ceiling cap
    function _add(uint256 score, uint256 delta) internal pure returns (uint256) {
        uint256 result = score + delta;
        return result > SCORE_CEILING ? SCORE_CEILING : result;
    }

    /// @notice Subtract with floor cap
    function _sub(uint256 score, uint256 delta) internal pure returns (uint256) {
        return score > delta ? score - delta : SCORE_FLOOR;
    }

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    function getReputation(uint256 agentId)
        external
        view
        override
        returns (ReputationState memory)
    {
        if (_reputations[agentId].registeredAt == 0) revert AgentNotInitialized(agentId);
        return _reputations[agentId];
    }

    function getScore(uint256 agentId) external view override returns (uint256) {
        if (_reputations[agentId].registeredAt == 0) revert AgentNotInitialized(agentId);
        return _reputations[agentId].score;
    }

    function getEventHistory(uint256 agentId)
        external
        view
        override
        returns (ReputationEvent[] memory)
    {
        return _eventHistory[agentId];
    }

    function getEventCount(uint256 agentId) external view override returns (uint256) {
        return _eventHistory[agentId].length;
    }

    function isAuthorizedUpdater(address updater) external view override returns (bool) {
        return _authorizedUpdaters[updater];
    }

    function isAgentInitialized(uint256 agentId) external view override returns (bool) {
        return _reputations[agentId].registeredAt != 0;
    }

    function getScoreWeights() external view override returns (
        uint256, uint256, uint256, uint256, uint256, uint256
    ) {
        return (
            taskCompleteWeight,
            taskFailWeight,
            positiveRatingWeight,
            negativeRatingWeight,
            disputeWonWeight,
            disputeLostWeight
        );
    }
}
