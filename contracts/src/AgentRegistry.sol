// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentRegistry} from "./interfaces/IAgentRegistry.sol";

/// @title AgentRegistry
/// @author Aditya Chotaliya [adityachotaliya.vercel.app]
/// @notice The identity system for autonomous AI agents on-chain
/// @dev Each agent gets a unique ID, maps to an owner EOA, and optionally an ERC-4337 smart wallet.
///      Extended metadata (name, description, capabilities, pricing) is stored on IPFS.
///
/// Security properties:
///   - One agent per owner address
///   - Only owner can update their agent
///   - Reputation can only be updated by authorized protocol contracts (Phase 2)
///   - Status transitions are validated
contract AgentRegistry is IAgentRegistry {
    // ============================================================
    //                         STORAGE
    // ============================================================

    /// @notice Protocol owner — can authorize reputation writers, pause, etc.
    address public immutable protocolOwner;

    /// @notice Auto-incrementing agent ID counter (starts at 1)
    uint256 private _nextAgentId;

    /// @notice agentId => AgentProfile
    mapping(uint256 => AgentProfile) private _agents;

    /// @notice owner address => agentId (0 means not registered)
    mapping(address => uint256) private _ownerToAgentId;

    /// @notice Addresses authorized to update reputation scores (Phase 2: marketplace, AVS)
    mapping(address => bool) public reputationUpdaters;

    // ============================================================
    //                       MODIFIERS
    // ============================================================

    modifier onlyProtocolOwner() {
        require(msg.sender == protocolOwner, "Not protocol owner");
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
        _nextAgentId = 1; // IDs start at 1
    }

    // ============================================================
    //                    REGISTRATION
    // ============================================================

    /// @notice Register a new AI agent on-chain
    /// @param metadataURI IPFS CID (e.g. "ipfs://Qm...") pointing to agent metadata JSON
    /// @param category The specialization category for this agent
    /// @return agentId The newly assigned unique agent ID
    function registerAgent(
        string calldata metadataURI,
        AgentCategory category
    ) external returns (uint256 agentId) {
        // One agent per address
        if (_ownerToAgentId[msg.sender] != 0) revert AgentAlreadyRegistered(msg.sender);
        if (bytes(metadataURI).length == 0) revert InvalidMetadataURI();

        agentId = _nextAgentId++;

        _agents[agentId] = AgentProfile({
            agentId: agentId,
            owner: msg.sender,
            agentWallet: address(0), // Set separately via setAgentWallet
            metadataURI: metadataURI,
            category: category,
            status: AgentStatus.ACTIVE,
            reputationScore: 5000, // Start at 50% (5000 basis points)
            totalTasksCompleted: 0,
            totalEarned: 0,
            registeredAt: block.timestamp,
            lastActiveAt: block.timestamp
        });

        _ownerToAgentId[msg.sender] = agentId;

        emit AgentRegistered(agentId, msg.sender, address(0), metadataURI, category);
    }

    // ============================================================
    //                      AGENT UPDATES
    // ============================================================

    /// @notice Update the IPFS metadata URI for an agent
    /// @dev Called when agent capabilities/pricing change — new IPFS upload, update CID here
    function updateMetadata(uint256 agentId, string calldata metadataURI)
        external
        onlyAgentOwner(agentId)
    {
        if (bytes(metadataURI).length == 0) revert InvalidMetadataURI();
        _agents[agentId].metadataURI = metadataURI;
        _agents[agentId].lastActiveAt = block.timestamp;

        emit AgentUpdated(agentId, metadataURI, _agents[agentId].status);
    }

    /// @notice Change agent lifecycle status
    function setAgentStatus(uint256 agentId, AgentStatus status)
        external
        onlyAgentOwner(agentId)
    {
        AgentStatus oldStatus = _agents[agentId].status;
        _agents[agentId].status = status;
        _agents[agentId].lastActiveAt = block.timestamp;

        emit AgentStatusChanged(agentId, oldStatus, status);
    }

    /// @notice Link an ERC-4337 smart wallet to this agent
    /// @dev Phase 1B: wallet is deployed separately, linked here
    function setAgentWallet(uint256 agentId, address wallet)
        external
        onlyAgentOwner(agentId)
    {
        if (wallet == address(0)) revert ZeroAddress();
        _agents[agentId].agentWallet = wallet;
        _agents[agentId].lastActiveAt = block.timestamp;

        emit AgentWalletSet(agentId, wallet);
    }

    // ============================================================
    //                  REPUTATION (PHASE 2 PREP)
    // ============================================================

    /// @notice Authorize a contract to update reputation (marketplace, AVS verifier)
    function setReputationUpdater(address updater, bool authorized) external onlyProtocolOwner {
        reputationUpdaters[updater] = authorized;
    }

    /// @notice Update agent reputation — only callable by authorized contracts
    /// @dev Phase 2: TaskMarketplace will call this after task completion
    function updateReputation(uint256 agentId, uint256 newScore, uint256 tasksCompleted, uint256 earned)
        external
        agentExists(agentId)
    {
        require(reputationUpdaters[msg.sender], "Not authorized to update reputation");
        require(newScore <= 10000, "Score exceeds max (10000 basis points)");

        _agents[agentId].reputationScore = newScore;
        _agents[agentId].totalTasksCompleted += tasksCompleted;
        _agents[agentId].totalEarned += earned;
        _agents[agentId].lastActiveAt = block.timestamp;
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
