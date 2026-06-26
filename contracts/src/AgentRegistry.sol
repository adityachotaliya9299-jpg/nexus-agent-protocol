// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentRegistry} from "./interfaces/IAgentRegistry.sol";

/// @title AgentRegistry
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice The identity system for autonomous AI agents on-chain
/// @dev Phase 11 gas optimizations applied:
///      - Custom errors replace require strings (~50 gas each)
///      - Storage pointer caching in updateReputation (avoids repeated keccak)
contract AgentRegistry is IAgentRegistry {
    // ============================================================
    //                         STORAGE
    // ============================================================

    address public immutable protocolOwner;

    uint256 private _nextAgentId;

    mapping(uint256 => AgentProfile) private _agents;
    mapping(address => uint256)      private _ownerToAgentId;
    mapping(address => bool)         public reputationUpdaters;

    // ============================================================
    //                       MODIFIERS
    // ============================================================

    modifier onlyProtocolOwner() {
        // OPT: custom error instead of require string
        if (msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    modifier onlyAgentOwner(uint256 agentId) {
        if (_agents[agentId].owner == address(0)) revert AgentNotFound(agentId);
        if (_agents[agentId].owner != msg.sender) revert NotAgentOwner(msg.sender, agentId);
        _;
    }

    modifier agentExists(uint256 agentId) {
        if (_agents[agentId].owner == address(0)) revert AgentNotFound(agentId);
        _;
    }

    // ============================================================
    //                       CONSTRUCTOR
    // ============================================================

    constructor(address _protocolOwner) {
        if (_protocolOwner == address(0)) revert ZeroAddress();
        protocolOwner = _protocolOwner;
        _nextAgentId  = 1;
    }

    // ============================================================
    //                    REGISTRATION
    // ============================================================

    function registerAgent(
        string calldata metadataURI,
        AgentCategory category
    ) external returns (uint256 agentId) {
        if (_ownerToAgentId[msg.sender] != 0) revert AgentAlreadyRegistered(msg.sender);
        if (bytes(metadataURI).length == 0) revert InvalidMetadataURI();

        agentId = _nextAgentId++;

        _agents[agentId] = AgentProfile({
            agentId:             agentId,
            owner:               msg.sender,
            agentWallet:         address(0),
            metadataURI:         metadataURI,
            category:            category,
            status:              AgentStatus.ACTIVE,
            reputationScore:     5000,
            totalTasksCompleted: 0,
            totalEarned:         0,
            registeredAt:        block.timestamp,
            lastActiveAt:        block.timestamp
        });

        _ownerToAgentId[msg.sender] = agentId;

        emit AgentRegistered(agentId, msg.sender, address(0), metadataURI, category);
    }

    // ============================================================
    //                      AGENT UPDATES
    // ============================================================

    function updateMetadata(uint256 agentId, string calldata metadataURI)
        external onlyAgentOwner(agentId)
    {
        if (bytes(metadataURI).length == 0) revert InvalidMetadataURI();

        // OPT: storage pointer — single keccak, multiple writes
        AgentProfile storage agent = _agents[agentId];
        agent.metadataURI  = metadataURI;
        agent.lastActiveAt = block.timestamp;

        emit AgentUpdated(agentId, metadataURI, agent.status);
    }

    function setAgentStatus(uint256 agentId, AgentStatus status)
        external onlyAgentOwner(agentId)
    {
        AgentProfile storage agent = _agents[agentId];
        AgentStatus oldStatus = agent.status;
        agent.status      = status;
        agent.lastActiveAt = block.timestamp;

        emit AgentStatusChanged(agentId, oldStatus, status);
    }

    function setAgentWallet(uint256 agentId, address wallet)
        external onlyAgentOwner(agentId)
    {
        if (wallet == address(0)) revert ZeroAddress();

        AgentProfile storage agent = _agents[agentId];
        agent.agentWallet  = wallet;
        agent.lastActiveAt = block.timestamp;

        emit AgentWalletSet(agentId, wallet);
    }

    // ============================================================
    //                  REPUTATION UPDATES
    // ============================================================

    function setReputationUpdater(address updater, bool authorized)
        external onlyProtocolOwner
    {
        reputationUpdaters[updater] = authorized;
    }

    function updateReputation(
        uint256 agentId,
        uint256 newScore,
        uint256 tasksCompleted,
        uint256 earned
    ) external agentExists(agentId) {
        // OPT: custom errors instead of require strings
        if (!reputationUpdaters[msg.sender]) revert NotAuthorized();
        if (newScore > 10000) revert InvalidScore();

        // OPT: single storage pointer — avoids 4x keccak hash computation
        AgentProfile storage agent = _agents[agentId];
        agent.reputationScore      = newScore;
        agent.totalTasksCompleted  += tasksCompleted;
        agent.totalEarned          += earned;
        agent.lastActiveAt         = block.timestamp;
    }

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    function getAgent(uint256 agentId) external view returns (AgentProfile memory) {
        if (_agents[agentId].owner == address(0)) revert AgentNotFound(agentId);
        return _agents[agentId];
    }

    function getAgentByOwner(address owner) external view returns (AgentProfile memory) {
        uint256 agentId = _ownerToAgentId[owner];
        if (agentId == 0) revert AgentNotFound(0);
        return _agents[agentId];
    }

    function getAgentIdByOwner(address owner) external view returns (uint256) {
        return _ownerToAgentId[owner];
    }

    function isRegistered(address owner) external view returns (bool) {
        return _ownerToAgentId[owner] != 0;
    }

    function totalAgents() external view returns (uint256) {
        return _nextAgentId - 1;
    }
}
