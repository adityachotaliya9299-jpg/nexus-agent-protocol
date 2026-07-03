// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentDiscovery} from "./IAgentDiscovery.sol";
import {IContextualReputation} from "../reputation/IContextualReputation.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";
import {IReputationOracle} from "../interfaces/IReputationOracle.sol";

/// @title AgentDiscovery
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice On-chain agent search, filtering, and leaderboard.
///
/// @dev All search is done in view functions — no state mutations needed.
///      This is intentionally not gas-optimized for writes since it's
///      called off-chain by frontends and the SDK. On-chain callers
///      should use `findBestAgent` which does O(n) but n is bounded.
///
///      Architecture:
///        - Maintains an indexed set of all active agent IDs
///        - Each search iterates the index and applies filters
///        - Leaderboard sorts by contextual score (insertion sort, bounded)
///        - findBestAgent returns the single best match in one call
///
///      For production scale: The Graph subgraph should index AgentIndexed
///      events and serve paginated results off-chain. This contract is the
///      source of truth; the subgraph is the fast query layer.
contract AgentDiscovery is IAgentDiscovery {

    // ── Constants ────────────────────────────────────────────────

    uint256 public constant MAX_LIMIT       = 50;
    uint256 public constant ANY_CATEGORY    = 255;
    uint256 public constant NUM_CATEGORIES  = 6;

    // ── Storage ──────────────────────────────────────────────────

    address public immutable protocolOwner;
    address public immutable registry;
    address public immutable reputationOracle;
    address public immutable contextualReputation;
    address public immutable agentStaking;

    mapping(address => bool) public isAuthorized;

    /// @notice All indexed agent IDs
    uint256[] private _indexedAgents;

    /// @notice agentId => index in _indexedAgents (1-based, 0 = not indexed)
    mapping(uint256 => uint256) private _agentIndex;

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

    constructor(
        address _protocolOwner,
        address _registry,
        address _reputationOracle,
        address _contextualReputation,
        address _agentStaking
    ) {
        if (_protocolOwner == address(0) || _registry == address(0)) revert ZeroAddress();
        protocolOwner         = _protocolOwner;
        registry              = _registry;
        reputationOracle      = _reputationOracle;
        contextualReputation  = _contextualReputation;
        agentStaking          = _agentStaking;
    }

    // ── Indexing ─────────────────────────────────────────────────

    function indexAgent(uint256 agentId) external override onlyAuthorized {
        if (_agentIndex[agentId] != 0) return; // already indexed

        _indexedAgents.push(agentId);
        _agentIndex[agentId] = _indexedAgents.length; // 1-based

        // Get agent category for event
        uint256 category = 0;
        try IAgentRegistry(registry).getAgent(agentId) returns (
            IAgentRegistry.AgentProfile memory profile
        ) {
            category = uint256(profile.category);
        } catch {}

        emit AgentIndexed(agentId, category);
    }

    function deindexAgent(uint256 agentId) external override onlyAuthorized {
        uint256 idx = _agentIndex[agentId];
        if (idx == 0) return; // not indexed

        // Swap with last element
        uint256 lastId = _indexedAgents[_indexedAgents.length - 1];
        _indexedAgents[idx - 1] = lastId;
        _agentIndex[lastId]     = idx;
        _indexedAgents.pop();
        _agentIndex[agentId] = 0;

        emit AgentDeindexed(agentId);
    }

    // ── Search ───────────────────────────────────────────────────

    function search(SearchFilter calldata filter, uint256 limit)
        external view override returns (AgentSearchResult[] memory results)
    {
        if (limit == 0 || limit > MAX_LIMIT) revert InvalidPageSize();

        AgentSearchResult[] memory temp = new AgentSearchResult[](limit);
        uint256 count = 0;

        for (uint256 i = 0; i < _indexedAgents.length && count < limit; i++) {
            uint256 agentId = _indexedAgents[i];
            AgentSearchResult memory result = _buildResult(agentId, filter.category);

            if (_matchesFilter(result, filter)) {
                temp[count++] = result;
            }
        }

        // Trim to actual count
        results = new AgentSearchResult[](count);
        for (uint256 i = 0; i < count; i++) {
            results[i] = temp[i];
        }
    }

    // ── Leaderboard ───────────────────────────────────────────────

    function getLeaderboard(uint256 category, uint256 limit)
        external view override returns (LeaderboardEntry[] memory entries)
    {
        if (limit == 0 || limit > MAX_LIMIT) revert InvalidPageSize();
        if (category >= NUM_CATEGORIES && category != ANY_CATEGORY) revert InvalidCategory();

        uint256 n = _indexedAgents.length < limit ? _indexedAgents.length : limit;
        entries = new LeaderboardEntry[](n);
        uint256 count = 0;

        for (uint256 i = 0; i < _indexedAgents.length; i++) {
            uint256 agentId = _indexedAgents[i];
            uint256 score;

            if (category == ANY_CATEGORY) {
                try IReputationOracle(reputationOracle).getScore(agentId) returns (uint256 s) {
                    score = s;
                } catch { score = 0; }
            } else {
                try IContextualReputation(contextualReputation).getScore(agentId, category)
                    returns (uint256 s) { score = s; }
                catch { score = 0; }
            }

            IAgentRegistry.AgentProfile memory profile;
            try IAgentRegistry(registry).getAgent(agentId) returns (
                IAgentRegistry.AgentProfile memory p
            ) { profile = p; }
            catch { continue; }

            LeaderboardEntry memory entry = LeaderboardEntry({
                agentId:        agentId,
                owner:          profile.owner,
                score:          score,
                rank:           0, // set after sort
                tasksCompleted: profile.totalTasksCompleted
            });

            // Insertion sort into entries array
            if (count < n) {
                entries[count++] = entry;
                // Bubble up
                uint256 j = count - 1;
                while (j > 0 && entries[j].score > entries[j-1].score) {
                    LeaderboardEntry memory tmp = entries[j];
                    entries[j]   = entries[j-1];
                    entries[j-1] = tmp;
                    j--;
                }
            } else if (score > entries[n-1].score) {
                entries[n-1] = entry;
                // Bubble up
                uint256 j = n - 1;
                while (j > 0 && entries[j].score > entries[j-1].score) {
                    LeaderboardEntry memory tmp = entries[j];
                    entries[j]   = entries[j-1];
                    entries[j-1] = tmp;
                    j--;
                }
            }
        }

        // Assign ranks
        for (uint256 i = 0; i < count; i++) {
            entries[i].rank = i + 1;
        }

        // Trim if fewer agents than limit
        if (count < n) {
            LeaderboardEntry[] memory trimmed = new LeaderboardEntry[](count);
            for (uint256 i = 0; i < count; i++) trimmed[i] = entries[i];
            return trimmed;
        }
    }

    // ── Single agent profile ──────────────────────────────────────

    function getAgentProfile(uint256 agentId)
        external view override returns (AgentSearchResult memory)
    {
        return _buildResult(agentId, ANY_CATEGORY);
    }

    // ── Find best agent ───────────────────────────────────────────

    function findBestAgent(uint256 category, uint256 minScore, uint256 minStake)
        external view override returns (uint256 agentId, uint256 score)
    {
        for (uint256 i = 0; i < _indexedAgents.length; i++) {
            uint256 id = _indexedAgents[i];

            uint256 s;
            try IContextualReputation(contextualReputation).getScore(id, category)
                returns (uint256 cs) { s = cs; }
            catch { continue; }

            if (s < minScore) continue;

            // Check stake if required
            if (minStake > 0 && agentStaking != address(0)) {
                // Simple balance check via low-level call to avoid ABI dependency
                (bool ok, bytes memory data) = agentStaking.staticcall(
                    abi.encodeWithSignature("getEffectiveStake(uint256)", id)
                );
                if (ok && data.length >= 32) {
                    uint256 stake = abi.decode(data, (uint256));
                    if (stake < minStake) continue;
                }
            }

            // Check agent is active
            try IAgentRegistry(registry).getAgent(id) returns (
                IAgentRegistry.AgentProfile memory p
            ) {
                if (uint256(p.status) != 1) continue; // 1 = ACTIVE
            } catch { continue; }

            if (s > score) {
                score   = s;
                agentId = id;
            }
        }
    }

    // ── Pagination ────────────────────────────────────────────────

    function totalIndexed() external view override returns (uint256) {
        return _indexedAgents.length;
    }

    function getIndexedAgents(uint256 offset, uint256 limit)
        external view override returns (uint256[] memory agentIds)
    {
        if (limit > MAX_LIMIT) revert InvalidPageSize();
        uint256 total = _indexedAgents.length;
        if (offset >= total) return new uint256[](0);

        uint256 end = offset + limit > total ? total : offset + limit;
        agentIds = new uint256[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            agentIds[i - offset] = _indexedAgents[i];
        }
    }

    // ── Admin ────────────────────────────────────────────────────

    function setAuthorized(address addr, bool auth) external onlyOwner {
        if (addr == address(0)) revert ZeroAddress();
        isAuthorized[addr] = auth;
    }

    // ── Internal ─────────────────────────────────────────────────

    function _buildResult(uint256 agentId, uint256 category)
        internal view returns (AgentSearchResult memory result)
    {
        result.agentId = agentId;

        try IAgentRegistry(registry).getAgent(agentId) returns (
            IAgentRegistry.AgentProfile memory p
        ) {
            result.owner               = p.owner;
            result.agentWallet         = p.agentWallet;
            result.category            = uint256(p.category);
            result.totalTasksCompleted = p.totalTasksCompleted;
            result.metadataURI         = p.metadataURI;
            result.isActive            = uint256(p.status) == 1;
        } catch { return result; }

        try IReputationOracle(reputationOracle).getScore(agentId) returns (uint256 s) {
            result.globalRepScore = s;
        } catch {}

        uint256 catToScore = category == ANY_CATEGORY ? result.category : category;
        if (catToScore < NUM_CATEGORIES) {
            try IContextualReputation(contextualReputation).getScore(agentId, catToScore)
                returns (uint256 cs) { result.contextualScore = cs; }
            catch {}
        }

        if (agentStaking != address(0)) {
            (bool ok, bytes memory data) = agentStaking.staticcall(
                abi.encodeWithSignature("getStake(uint256)", agentId)
            );
            if (ok && data.length >= 64) {
                // totalStaked is second field in StakeInfo struct
                (, uint256 totalStaked) = abi.decode(data, (uint256, uint256));
                result.stakedAmount = totalStaked;
            }
            (bool ok2, bytes memory data2) = agentStaking.staticcall(
                abi.encodeWithSignature("getEffectiveStake(uint256)", agentId)
            );
            if (ok2 && data2.length >= 32) {
                result.effectiveStake = abi.decode(data2, (uint256));
            }
        }
    }

    function _matchesFilter(AgentSearchResult memory r, SearchFilter calldata f)
        internal pure returns (bool)
    {
        if (f.activeOnly && !r.isActive) return false;
        if (f.category != ANY_CATEGORY && r.category != f.category) return false;
        if (r.contextualScore < f.minContextualScore) return false;
        if (r.globalRepScore  < f.minGlobalScore)     return false;
        if (r.stakedAmount    < f.minStake)            return false;
        if (r.totalTasksCompleted < f.minTasksCompleted) return false;
        return true;
    }
}
