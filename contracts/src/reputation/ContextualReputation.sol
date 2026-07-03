// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IContextualReputation} from "./IContextualReputation.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";

/// @title ContextualReputation
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Per-category reputation scoring with client ratings and streak bonuses.
///
/// @dev Score formula per category:
///
///   baseScore    = (successRate * 6000) / 10000   → max 6000 from success rate
///   ratingScore  = (avgRating   * 3000) / 10000   → max 3000 from client ratings
///   streakBonus  = min(streak * 50, 1000)          → max 1000 from consecutive wins
///   TOTAL        = baseScore + ratingScore + streakBonus  → max 10000
///
///   successRate  = (tasksCompleted / tasksAssigned) * 10000
///   avgRating    = totalRatings / ratingCount
///
///   This means:
///     - An agent who completes 100% of tasks + gets 10000 avg rating + 20-streak = 10000
///     - An agent who fails half their tasks can never exceed 5000 from base alone
///     - Client ratings matter (3000 weight) but can't compensate for bad success rate
contract ContextualReputation is IContextualReputation {

    uint256 public constant NUM_CATEGORIES      = 6;
    uint256 public constant BASE_WEIGHT         = 6000;
    uint256 public constant RATING_WEIGHT       = 3000;
    uint256 public constant STREAK_BONUS_PER    = 50;
    uint256 public constant MAX_STREAK_BONUS    = 1000;
    uint256 public constant INITIAL_SCORE       = 5000;

    // ── Storage ──────────────────────────────────────────────────

    address public immutable protocolOwner;
    address public immutable registry;

    mapping(address => bool) public isAuthorized;

    /// @notice agentId => category => CategoryScore
    mapping(uint256 => mapping(uint256 => CategoryScore)) private _scores;

    /// @notice rater => agentId => taskId => rated (prevent double rating)
    mapping(address => mapping(uint256 => mapping(bytes32 => bool))) private _hasRated;

    // ── Modifiers ────────────────────────────────────────────────

    modifier onlyOwner() {
        if (msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    modifier onlyAuthorized() {
        if (!isAuthorized[msg.sender] && msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    // ── Constructor ───────────────────────────────────────────────

    constructor(address _protocolOwner, address _registry) {
        if (_protocolOwner == address(0) || _registry == address(0)) revert ZeroAddress();
        protocolOwner = _protocolOwner;
        registry      = _registry;
    }

    // ── Record Completion ─────────────────────────────────────────

    /// @notice Record a task completion or failure for a specific category
    function recordCompletion(uint256 agentId, uint256 category, bool success)
        external override onlyAuthorized
    {
        if (category >= NUM_CATEGORIES) revert InvalidCategory(category);
        _requireAgentExists(agentId);

        CategoryScore storage cs = _scores[agentId][category];
        if (cs.agentId == 0) _initScore(agentId, category, cs);

        uint256 oldScore = cs.score;
        cs.tasksAssigned++;

        if (success) {
            cs.tasksCompleted++;
            cs.streak++;
        } else {
            cs.streak = 0; // streak broken on failure
        }

        cs.score          = _computeScore(cs);
        cs.lastUpdatedAt  = block.timestamp;

        emit CategoryScoreUpdated(agentId, category, oldScore, cs.score, cs.tasksCompleted);
    }

    // ── Submit Rating ─────────────────────────────────────────────

    /// @notice Client rates an agent after task completion (0–10000)
    function submitRating(
        uint256 agentId,
        uint256 category,
        uint256 rating,
        bytes32 taskId
    ) external override {
        if (category >= NUM_CATEGORIES) revert InvalidCategory(category);
        if (rating > 10000) revert InvalidRating(rating);
        if (_hasRated[msg.sender][agentId][taskId]) revert AlreadyRated(msg.sender, agentId, taskId);
        _requireAgentExists(agentId);

        _hasRated[msg.sender][agentId][taskId] = true;

        CategoryScore storage cs = _scores[agentId][category];
        if (cs.agentId == 0) _initScore(agentId, category, cs);

        uint256 oldScore  = cs.score;
        cs.totalRatings  += rating;
        cs.ratingCount++;
        cs.score          = _computeScore(cs);
        cs.lastUpdatedAt  = block.timestamp;

        emit RatingSubmitted(agentId, category, rating, msg.sender);
        emit CategoryScoreUpdated(agentId, category, oldScore, cs.score, cs.tasksCompleted);
    }

    // ── View Functions ────────────────────────────────────────────

    function getCategoryScore(uint256 agentId, uint256 category)
        external view override returns (CategoryScore memory)
    {
        return _scores[agentId][category];
    }

    function getScore(uint256 agentId, uint256 category)
        external view override returns (uint256)
    {
        CategoryScore storage cs = _scores[agentId][category];
        if (cs.agentId == 0) return INITIAL_SCORE;
        return cs.score;
    }

    function getProfile(uint256 agentId)
        external view override returns (AgentContextualProfile memory profile)
    {
        profile.agentId = agentId;
        uint256 totalScore;
        uint256 activeCategories;

        for (uint256 i = 0; i < NUM_CATEGORIES; i++) {
            CategoryScore storage cs = _scores[agentId][i];
            uint256 score = cs.agentId == 0 ? 0 : cs.score;
            profile.categoryScores[i] = score;
            if (score > 0) {
                totalScore += score;
                activeCategories++;
                if (score > profile.bestScore) {
                    profile.bestScore    = score;
                    profile.bestCategory = i;
                }
            }
        }

        profile.globalAverage = activeCategories > 0
            ? totalScore / activeCategories
            : 0;
    }

    function getBestCategory(uint256 agentId)
        external view override returns (uint256 category, uint256 score)
    {
        for (uint256 i = 0; i < NUM_CATEGORIES; i++) {
            uint256 s = _scores[agentId][i].score;
            if (s > score) {
                score    = s;
                category = i;
            }
        }
    }

    function meetsRequirement(uint256 agentId, uint256 category, uint256 minScore)
        external view override returns (bool)
    {
        if (category >= NUM_CATEGORIES) return false;
        CategoryScore storage cs = _scores[agentId][category];
        uint256 score = cs.agentId == 0 ? INITIAL_SCORE : cs.score;
        return score >= minScore;
    }

    // ── Admin ────────────────────────────────────────────────────

    function setAuthorized(address addr, bool auth) external onlyOwner {
        if (addr == address(0)) revert ZeroAddress();
        isAuthorized[addr] = auth;
    }

    // ── Internal ─────────────────────────────────────────────────

    function _initScore(uint256 agentId, uint256 category, CategoryScore storage cs) internal {
        cs.agentId       = agentId;
        cs.category      = category;
        cs.score         = INITIAL_SCORE;
        cs.lastUpdatedAt = block.timestamp;
    }

    function _computeScore(CategoryScore storage cs) internal view returns (uint256) {
        // Success rate component (0–6000)
        uint256 successRate = cs.tasksAssigned > 0
            ? (cs.tasksCompleted * 10000) / cs.tasksAssigned
            : 10000; // No tasks = assume perfect (no evidence of failure)
        uint256 baseScore = (successRate * BASE_WEIGHT) / 10000;

        // Rating component (0–3000)
        uint256 avgRating = cs.ratingCount > 0
            ? cs.totalRatings / cs.ratingCount
            : 5000; // No ratings = assume neutral
        uint256 ratingScore = (avgRating * RATING_WEIGHT) / 10000;

        // Streak bonus (0–1000)
        uint256 streakBonus = cs.streak * STREAK_BONUS_PER;
        if (streakBonus > MAX_STREAK_BONUS) streakBonus = MAX_STREAK_BONUS;

        uint256 total = baseScore + ratingScore + streakBonus;
        return total > 10000 ? 10000 : total;
    }

    function _requireAgentExists(uint256 agentId) internal view {
        try IAgentRegistry(registry).getAgent(agentId) returns (IAgentRegistry.AgentProfile memory) {}
        catch { revert AgentNotFound(agentId); }
    }
}
