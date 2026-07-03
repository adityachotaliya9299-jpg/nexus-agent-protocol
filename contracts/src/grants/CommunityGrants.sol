// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICommunityGrants} from "./ICommunityGrants.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";
import {IReputationOracle} from "../interfaces/IReputationOracle.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title CommunityGrants
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Community treasury with reputation-weighted grant voting.
///
/// @dev Voting power = agent reputation score (same model as NexusGovernor).
///      Any registered agent can propose a grant.
///      Grants pass with: quorum 10% of total rep + simple majority FOR.
///      Timelock: 24h between approval and execution.
///
///      Fee routing: protocol contracts call deposit() with a source label.
///      This creates an on-chain audit trail of where treasury funds came from.
contract CommunityGrants is ICommunityGrants, ReentrancyGuard {

    uint256 public constant VOTING_PERIOD   = 3 days;
    uint256 public constant TIMELOCK        = 24 hours;
    uint256 public constant QUORUM_BPS      = 1000;    // 10% of max voting power

    address public immutable protocolOwner;
    address public immutable registry;
    address public immutable reputationOracle;

    mapping(address => bool) public isAuthorized;

    mapping(bytes32 => Grant)           private _grants;
    mapping(bytes32 => mapping(uint256 => bool)) private _voted;
    bytes32[] private _activeGrants;
    bytes32[] private _allGrants;

    uint256 public override totalDeposited;
    uint256 public override totalGranted;
    uint256 private _nonce;

    modifier onlyOwner() {
        if (msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    receive() external payable {
        totalDeposited += msg.value;
        emit FeeDeposited(msg.sender, msg.value, "direct");
    }

    constructor(
        address _protocolOwner,
        address _registry,
        address _reputationOracle
    ) {
        if (_protocolOwner == address(0) || _registry == address(0) ||
            _reputationOracle == address(0)) revert ZeroAddress();
        protocolOwner    = _protocolOwner;
        registry         = _registry;
        reputationOracle = _reputationOracle;
    }

    // ── Deposit ───────────────────────────────────────────────────

    function deposit(string calldata source) external payable override {
        if (msg.value == 0) revert ZeroAmount();
        totalDeposited += msg.value;
        emit FeeDeposited(msg.sender, msg.value, source);
    }

    // ── Propose Grant ─────────────────────────────────────────────

    function proposeGrant(
        string calldata title,
        string calldata description,
        address recipient,
        uint256 amount,
        GrantType grantType,
        uint256 proposerAgentId
    ) external override returns (bytes32 grantId) {
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        // Verify proposer owns their agent
        IAgentRegistry.AgentProfile memory profile =
            IAgentRegistry(registry).getAgent(proposerAgentId);
        if (profile.owner != msg.sender) revert NotAuthorized();

        grantId = keccak256(abi.encodePacked("grant", msg.sender, _nonce++, block.timestamp));

        _grants[grantId] = Grant({
            grantId:      grantId,
            title:        title,
            description:  description,
            recipient:    recipient,
            amount:       amount,
            grantType:    grantType,
            status:       GrantStatus.VOTING,
            proposedBy:   proposerAgentId,
            forVotes:     0,
            againstVotes: 0,
            votingEndsAt: block.timestamp + VOTING_PERIOD,
            proposedAt:   block.timestamp,
            executedAt:   0
        });

        _activeGrants.push(grantId);
        _allGrants.push(grantId);

        emit GrantProposed(grantId, title, amount, recipient);
    }

    // ── Vote ──────────────────────────────────────────────────────

    function voteOnGrant(bytes32 grantId, uint256 agentId, bool support) external override {
        Grant storage g = _grants[grantId];
        if (g.proposedAt == 0) revert GrantNotFound(grantId);
        if (g.status != GrantStatus.VOTING) revert VotingNotActive(grantId);
        if (block.timestamp > g.votingEndsAt) revert VotingNotActive(grantId);
        if (_voted[grantId][agentId]) revert AlreadyVoted(grantId, agentId);

        IAgentRegistry.AgentProfile memory profile =
            IAgentRegistry(registry).getAgent(agentId);
        if (profile.owner != msg.sender) revert NotAuthorized();

        uint256 weight = _getScore(agentId);
        _voted[grantId][agentId] = true;

        if (support) g.forVotes     += weight;
        else         g.againstVotes += weight;

        emit GrantVoteCast(grantId, agentId, support, weight);
    }

    // ── Finalize ──────────────────────────────────────────────────

    function finalizeGrant(bytes32 grantId) external override {
        Grant storage g = _grants[grantId];
        if (g.proposedAt == 0) revert GrantNotFound(grantId);
        if (g.status != GrantStatus.VOTING) revert VotingNotActive(grantId);
        if (block.timestamp <= g.votingEndsAt) revert VotingNotActive(grantId);

        // Check quorum
        uint256 totalAgents = IAgentRegistry(registry).totalAgents();
        uint256 maxPower    = totalAgents * 10000;
        uint256 totalCast   = g.forVotes + g.againstVotes;
        bool quorumMet      = maxPower > 0 && (totalCast * 10000) >= (maxPower * QUORUM_BPS);

        if (!quorumMet) {
            g.status = GrantStatus.REJECTED;
            _removeFromActive(grantId);
            emit GrantRejected(grantId);
            return;
        }

        if (g.forVotes > g.againstVotes) {
            g.status       = GrantStatus.APPROVED;
            g.votingEndsAt = block.timestamp + TIMELOCK; // reuse as execution-ready timestamp
            emit GrantApproved(grantId, g.amount);
        } else {
            g.status = GrantStatus.REJECTED;
            _removeFromActive(grantId);
            emit GrantRejected(grantId);
        }
    }

    // ── Execute ───────────────────────────────────────────────────

    function executeGrant(bytes32 grantId) external override nonReentrant {
        Grant storage g = _grants[grantId];
        if (g.proposedAt == 0) revert GrantNotFound(grantId);
        if (g.status != GrantStatus.APPROVED) revert GrantNotApproved(grantId);
        if (block.timestamp < g.votingEndsAt) revert VotingNotActive(grantId); // timelock
        if (g.amount > address(this).balance) {
            revert InsufficientTreasury(g.amount, address(this).balance);
        }

        g.status     = GrantStatus.EXECUTED;
        g.executedAt = block.timestamp;
        totalGranted += g.amount;

        _removeFromActive(grantId);

        (bool ok,) = payable(g.recipient).call{value: g.amount}("");
        require(ok, "Transfer failed");

        emit GrantExecuted(grantId, g.recipient, g.amount);
    }

    // ── View Functions ────────────────────────────────────────────

    function getGrant(bytes32 grantId) external view override returns (Grant memory) {
        if (_grants[grantId].proposedAt == 0) revert GrantNotFound(grantId);
        return _grants[grantId];
    }

    function balance() external view override returns (uint256) {
        return address(this).balance;
    }

    function totalGrants() external view override returns (uint256) {
        return _allGrants.length;
    }

    function getActiveGrants() external view override returns (bytes32[] memory) {
        return _activeGrants;
    }

    // ── Admin ────────────────────────────────────────────────────

    function setAuthorized(address addr, bool auth) external onlyOwner {
        if (addr == address(0)) revert ZeroAddress();
        isAuthorized[addr] = auth;
    }

    // ── Internal ─────────────────────────────────────────────────

    function _getScore(uint256 agentId) internal view returns (uint256) {
        try IReputationOracle(reputationOracle).getScore(agentId) returns (uint256 s) {
            return s;
        } catch { return 0; }
    }

    function _removeFromActive(bytes32 grantId) internal {
        for (uint256 i = 0; i < _activeGrants.length; i++) {
            if (_activeGrants[i] == grantId) {
                _activeGrants[i] = _activeGrants[_activeGrants.length - 1];
                _activeGrants.pop();
                return;
            }
        }
    }
}
