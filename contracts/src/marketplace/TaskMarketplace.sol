// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ITaskMarketplace} from "../interfaces/ITaskMarketplace.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";
import {IReputationOracle} from "../interfaces/IReputationOracle.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title TaskMarketplace
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice The core task economy — agents post bids, get hired, submit work, get paid
///
/// @dev Full task lifecycle:
///   1. Client calls postTask{value: reward} → task enters OPEN state, ETH held in escrow
///   2. Registered agents call submitBid() → propose to do the task
///   3. Client calls assignAgent() → task enters ASSIGNED, agent is locked in
///   4. Agent calls submitWork() with result IPFS CID → task enters SUBMITTED
///   5a. Client calls approveWork() → COMPLETED, agent wallet receives payment minus fee
///   5b. Either party calls raiseDispute() → DISPUTED
///   6. Arbitrator calls resolveDispute() → RESOLVED, funds split per outcome
///
/// Escrow security:
///   - All ETH held in contract until task completion
///   - Cancellation before assignment → full refund to client
///   - No partial payments without dispute resolution
///
/// Agent-to-agent payments:
///   - assignedAgentWallet is the ERC-4337 smart wallet
///   - Payment sent directly to agent wallet (not owner EOA)
///
/// Fee model:
///   - platformFeeBps taken from reward on completion
///   - Fees accumulate in contract, withdrawn by protocol owner
contract TaskMarketplace is ITaskMarketplace, ReentrancyGuard {
    // ============================================================
    //                       CONSTANTS
    // ============================================================

    uint256 public constant MAX_FEE_BPS = 1000;    // Max 10% platform fee
    uint256 public constant MIN_DEADLINE = 1 hours; // Min task deadline from now
    uint256 public constant MAX_DEADLINE = 365 days;

    // ============================================================
    //                         STORAGE
    // ============================================================

    address public immutable protocolOwner;
    address public immutable registry;
    address public immutable reputationOracle;

    /// @notice Arbitrator address — resolves disputes
    address public arbitrator;

    /// @notice Platform fee in basis points (default: 250 = 2.5%)
    uint256 public override platformFeeBps;

    /// @notice Accumulated protocol fees awaiting withdrawal
    uint256 public accumulatedFees;

    uint256 public override totalTasksPosted;
    uint256 public override totalTasksCompleted;

    /// @notice taskId => Task
    mapping(bytes32 => Task) private _tasks;

    /// @notice taskId => agentId => Bid
    mapping(bytes32 => mapping(uint256 => Bid)) private _bids;

    /// @notice taskId => list of agentIds that bid
    mapping(bytes32 => uint256[]) private _taskBidders;

    /// @notice taskId => Dispute
    mapping(bytes32 => Dispute) private _disputes;

    /// @notice agentId => list of taskIds assigned to this agent
    mapping(uint256 => bytes32[]) private _agentTasks;

    /// @notice client address => list of taskIds posted by client
    mapping(address => bytes32[]) private _clientTasks;

    /// @notice Nonce for deterministic taskId generation
    uint256 private _taskNonce;

    // ============================================================
    //                       MODIFIERS
    // ============================================================

    modifier onlyProtocolOwner() {
        require(msg.sender == protocolOwner, "Not protocol owner");
        _;
    }

    modifier onlyArbitrator() {
        if (msg.sender != arbitrator) revert NotArbitrator();
        _;
    }

    modifier taskExists(bytes32 taskId) {
        if (_tasks[taskId].client == address(0)) revert TaskNotFound(taskId);
        _;
    }

    // ============================================================
    //                       CONSTRUCTOR
    // ============================================================

    constructor(
        address _protocolOwner,
        address _registry,
        address _reputationOracle,
        address _arbitrator,
        uint256 _platformFeeBps
    ) {
        if (_protocolOwner == address(0) || _registry == address(0) ||
            _reputationOracle == address(0) || _arbitrator == address(0)) {
            revert ZeroAddress();
        }
        if (_platformFeeBps > MAX_FEE_BPS) revert InvalidFee();

        protocolOwner      = _protocolOwner;
        registry           = _registry;
        reputationOracle   = _reputationOracle;
        arbitrator         = _arbitrator;
        platformFeeBps     = _platformFeeBps;
    }

    // ============================================================
    //                      POST TASK
    // ============================================================

    /// @notice Post a new task with ETH reward held in escrow
    /// @param metadataURI IPFS CID of task description (requirements, deliverables)
    /// @param deadline Unix timestamp by which task must be completed
    /// @param minReputation Minimum agent reputation score to bid (0 = no requirement)
    /// @return taskId Unique identifier for this task
    function postTask(
        string calldata metadataURI,
        uint256 deadline,
        uint256 minReputation
    ) external payable override nonReentrant returns (bytes32 taskId) {
        if (msg.value == 0) revert InvalidReward();
        if (bytes(metadataURI).length == 0) revert InvalidMetadata();
        if (deadline < block.timestamp + MIN_DEADLINE) revert InvalidDeadline();
        if (deadline > block.timestamp + MAX_DEADLINE) revert InvalidDeadline();

        // Generate deterministic taskId
        taskId = keccak256(abi.encodePacked(msg.sender, _taskNonce++, block.timestamp));

        uint256 fee = (msg.value * platformFeeBps) / 10000;

        _tasks[taskId] = Task({
            taskId: taskId,
            client: msg.sender,
            clientAgentId: 0,
            metadataURI: metadataURI,
            reward: msg.value,
            deadline: deadline,
            createdAt: block.timestamp,
            assignedAt: 0,
            submittedAt: 0,
            completedAt: 0,
            status: TaskStatus.OPEN,
            assignedAgentId: 0,
            assignedAgentWallet: address(0),
            platformFee: fee,
            requiresMinReputation: minReputation > 0,
            minReputation: minReputation
        });

        _clientTasks[msg.sender].push(taskId);
        totalTasksPosted++;

        emit TaskPosted(taskId, msg.sender, msg.value, deadline, metadataURI);
    }

    // ============================================================
    //                      SUBMIT BID
    // ============================================================

    /// @notice Agent submits a bid for an open task
    /// @param taskId The task to bid on
    /// @param agentId The bidding agent's registry ID
    /// @param proposalURI IPFS CID of the agent's proposal
    /// @param estimatedTime Estimated seconds to complete
    function submitBid(
        bytes32 taskId,
        uint256 agentId,
        string calldata proposalURI,
        uint256 estimatedTime
    ) external override taskExists(taskId) {
        Task storage task = _tasks[taskId];

        if (task.status != TaskStatus.OPEN) revert TaskNotOpen(taskId);
        if (block.timestamp >= task.deadline) revert DeadlinePassed(taskId);
        if (bytes(proposalURI).length == 0) revert InvalidMetadata();

        // Verify agent is registered and caller is the agent owner
        IAgentRegistry.AgentProfile memory profile = _getAgentProfile(agentId);
        if (profile.owner != msg.sender) revert AgentNotRegistered(agentId);

        // Agent cannot bid on their own task
        if (task.client == msg.sender) revert CannotBidOwnTask();

        // Check min reputation
        if (task.requiresMinReputation) {
            uint256 score = _getAgentScore(agentId);
            if (score < task.minReputation) {
                revert InsufficientReputation(agentId, task.minReputation, score);
            }
        }

        // Prevent duplicate bids
        if (_bids[taskId][agentId].submittedAt != 0 && !_bids[taskId][agentId].isWithdrawn) {
            revert BidAlreadyExists(taskId, agentId);
        }

        _bids[taskId][agentId] = Bid({
            taskId: taskId,
            agentId: agentId,
            agentWallet: profile.agentWallet,
            proposedReward: task.reward,
            proposalURI: proposalURI,
            estimatedTime: estimatedTime,
            submittedAt: block.timestamp,
            isAccepted: false,
            isWithdrawn: false
        });

        _taskBidders[taskId].push(agentId);

        emit BidSubmitted(taskId, agentId, task.reward);
    }

    // ============================================================
    //                      WITHDRAW BID
    // ============================================================

    function withdrawBid(bytes32 taskId, uint256 agentId)
        external
        override
        taskExists(taskId)
    {
        Task storage task = _tasks[taskId];
        if (task.status != TaskStatus.OPEN) revert TaskNotOpen(taskId);

        Bid storage bid = _bids[taskId][agentId];
        if (bid.submittedAt == 0) revert BidNotFound(taskId, agentId);
        if (bid.isWithdrawn) revert BidWithdrawnAlready(taskId, agentId);

        IAgentRegistry.AgentProfile memory profile = _getAgentProfile(agentId);
        if (profile.owner != msg.sender) revert AgentNotRegistered(agentId);

        bid.isWithdrawn = true;

        emit BidWithdrawn(taskId, agentId);
    }

    // ============================================================
    //                      ASSIGN AGENT
    // ============================================================

    /// @notice Client selects a bid and assigns the task to an agent
    function assignAgent(bytes32 taskId, uint256 agentId)
        external
        override
        taskExists(taskId)
        nonReentrant
    {
        Task storage task = _tasks[taskId];

        if (task.status != TaskStatus.OPEN) revert TaskNotOpen(taskId);
        if (task.client != msg.sender) revert NotTaskClient(taskId, msg.sender);
        if (block.timestamp >= task.deadline) revert DeadlinePassed(taskId);

        Bid storage bid = _bids[taskId][agentId];
        if (bid.submittedAt == 0) revert BidNotFound(taskId, agentId);
        if (bid.isWithdrawn) revert BidWithdrawnAlready(taskId, agentId);

        IAgentRegistry.AgentProfile memory profile = _getAgentProfile(agentId);

        task.status = TaskStatus.ASSIGNED;
        task.assignedAgentId = agentId;
        task.assignedAgentWallet = profile.agentWallet;
        task.assignedAt = block.timestamp;

        bid.isAccepted = true;

        _agentTasks[agentId].push(taskId);

        emit TaskAssigned(taskId, agentId, profile.agentWallet);
    }

    // ============================================================
    //                      SUBMIT WORK
    // ============================================================

    /// @notice Assigned agent submits completed work
    function submitWork(bytes32 taskId, uint256 agentId, string calldata resultURI)
        external
        override
        taskExists(taskId)
    {
        Task storage task = _tasks[taskId];

        if (task.status != TaskStatus.ASSIGNED) revert TaskNotAssigned(taskId);
        if (task.assignedAgentId != agentId) revert NotAssignedAgent(taskId, msg.sender);
        if (bytes(resultURI).length == 0) revert InvalidMetadata();

        IAgentRegistry.AgentProfile memory profile = _getAgentProfile(agentId);
        if (profile.owner != msg.sender) revert NotAssignedAgent(taskId, msg.sender);

        task.status = TaskStatus.SUBMITTED;
        task.submittedAt = block.timestamp;

        emit WorkSubmitted(taskId, agentId, resultURI);
    }

    // ============================================================
    //                      APPROVE WORK
    // ============================================================

    /// @notice Client approves submitted work → releases payment to agent
    function approveWork(bytes32 taskId)
        external
        override
        taskExists(taskId)
        nonReentrant
    {
        Task storage task = _tasks[taskId];

        if (task.status != TaskStatus.SUBMITTED) revert TaskNotSubmitted(taskId);
        if (task.client != msg.sender) revert NotTaskClient(taskId, msg.sender);

        task.status = TaskStatus.COMPLETED;
        task.completedAt = block.timestamp;
        totalTasksCompleted++;

        uint256 fee = task.platformFee;
        uint256 agentPayment = task.reward - fee;

        accumulatedFees += fee;

        // Pay agent wallet directly
        address payable agentWallet = payable(task.assignedAgentWallet);
        (bool success,) = agentWallet.call{value: agentPayment}("");
        if (!success) revert EscrowTransferFailed();

        // Update reputation via oracle
        _updateAgentReputation(task.assignedAgentId, IReputationOracle.UpdateReason.TASK_COMPLETED, taskId);

        emit TaskCompleted(taskId, task.assignedAgentId, agentPayment, fee);
    }

    // ============================================================
    //                      CANCEL TASK
    // ============================================================

    /// @notice Cancel task — only before assignment, full refund to client
    function cancelTask(bytes32 taskId)
        external
        override
        taskExists(taskId)
        nonReentrant
    {
        Task storage task = _tasks[taskId];

        // Only client can cancel, and only if OPEN
        if (task.client != msg.sender) revert NotTaskClient(taskId, msg.sender);
        if (task.status != TaskStatus.OPEN) revert TaskNotOpen(taskId);

        task.status = TaskStatus.CANCELLED;

        // Full refund to client
        (bool success,) = payable(msg.sender).call{value: task.reward}("");
        if (!success) revert EscrowTransferFailed();

        emit TaskCancelled(taskId, msg.sender);
    }

    // ============================================================
    //                      DISPUTE
    // ============================================================

    /// @notice Client or agent raises a dispute on a submitted task
    function raiseDispute(bytes32 taskId, string calldata reasonURI)
        external
        override
        taskExists(taskId)
    {
        Task storage task = _tasks[taskId];

        // Only client or assigned agent can raise dispute
        bool isClient = task.client == msg.sender;
        bool isAgent = false;
        if (task.assignedAgentId != 0) {
            IAgentRegistry.AgentProfile memory profile = _getAgentProfile(task.assignedAgentId);
            isAgent = profile.owner == msg.sender;
        }

        require(isClient || isAgent, "Not client or agent");
        if (task.status != TaskStatus.SUBMITTED && task.status != TaskStatus.ASSIGNED) {
            revert TaskNotSubmitted(taskId);
        }
        if (_disputes[taskId].raisedAt != 0) revert AlreadyDisputed(taskId);
        if (bytes(reasonURI).length == 0) revert InvalidMetadata();

        task.status = TaskStatus.DISPUTED;

        _disputes[taskId] = Dispute({
            taskId: taskId,
            raisedBy: msg.sender,
            reasonURI: reasonURI,
            raisedAt: block.timestamp,
            outcome: DisputeOutcome.NONE,
            resolvedBy: address(0),
            resolvedAt: 0,
            clientShare: 0
        });

        emit DisputeRaised(taskId, msg.sender, reasonURI);
    }

    /// @notice Arbitrator resolves a dispute
    function resolveDispute(
        bytes32 taskId,
        DisputeOutcome outcome,
        uint256 clientShareBps
    ) external override onlyArbitrator taskExists(taskId) nonReentrant {
        Task storage task = _tasks[taskId];
        if (task.status != TaskStatus.DISPUTED) revert TaskNotDisputed(taskId);

        Dispute storage dispute = _disputes[taskId];
        dispute.outcome = outcome;
        dispute.resolvedBy = msg.sender;
        dispute.resolvedAt = block.timestamp;
        dispute.clientShare = clientShareBps;

        task.status = TaskStatus.RESOLVED;
        task.completedAt = block.timestamp;

        uint256 totalAmount = task.reward;

        if (outcome == DisputeOutcome.CLIENT_WINS) {
            // Full refund to client
            (bool ok,) = payable(task.client).call{value: totalAmount}("");
            if (!ok) revert EscrowTransferFailed();
            _updateAgentReputation(task.assignedAgentId, IReputationOracle.UpdateReason.DISPUTE_LOST, taskId);

        } else if (outcome == DisputeOutcome.AGENT_WINS) {
            // Full payment to agent (minus platform fee)
            uint256 fee = task.platformFee;
            uint256 agentPayment = totalAmount - fee;
            accumulatedFees += fee;
            totalTasksCompleted++;
            (bool ok,) = payable(task.assignedAgentWallet).call{value: agentPayment}("");
            if (!ok) revert EscrowTransferFailed();
            _updateAgentReputation(task.assignedAgentId, IReputationOracle.UpdateReason.DISPUTE_WON, taskId);

        } else if (outcome == DisputeOutcome.SPLIT) {
            require(clientShareBps <= 10000, "Invalid split");
            uint256 clientAmount = (totalAmount * clientShareBps) / 10000;
            uint256 agentAmount = totalAmount - clientAmount;
            if (clientAmount > 0) {
                (bool ok1,) = payable(task.client).call{value: clientAmount}("");
                if (!ok1) revert EscrowTransferFailed();
            }
            if (agentAmount > 0) {
                (bool ok2,) = payable(task.assignedAgentWallet).call{value: agentAmount}("");
                if (!ok2) revert EscrowTransferFailed();
            }
        }

        emit DisputeResolved(taskId, outcome, msg.sender);
    }

    // ============================================================
    //                    ADMIN FUNCTIONS
    // ============================================================

    function setPlatformFee(uint256 newFeeBps) external onlyProtocolOwner {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(newFeeBps);
    }

    function setArbitrator(address newArbitrator) external onlyProtocolOwner {
        if (newArbitrator == address(0)) revert ZeroAddress();
        arbitrator = newArbitrator;
    }

    function withdrawFees(address payable to) external onlyProtocolOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        accumulatedFees = 0;
        (bool ok,) = to.call{value: amount}("");
        require(ok, "Fee withdrawal failed");
    }

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    function getTask(bytes32 taskId) external view override returns (Task memory) {
        if (_tasks[taskId].client == address(0)) revert TaskNotFound(taskId);
        return _tasks[taskId];
    }

    function getBid(bytes32 taskId, uint256 agentId)
        external view override returns (Bid memory)
    {
        return _bids[taskId][agentId];
    }

    function getTaskBids(bytes32 taskId)
        external view override returns (Bid[] memory)
    {
        uint256[] storage bidderIds = _taskBidders[taskId];
        Bid[] memory bids = new Bid[](bidderIds.length);
        for (uint256 i = 0; i < bidderIds.length; i++) {
            bids[i] = _bids[taskId][bidderIds[i]];
        }
        return bids;
    }

    function getDispute(bytes32 taskId)
        external view override returns (Dispute memory)
    {
        return _disputes[taskId];
    }

    function getAgentTasks(uint256 agentId)
        external view override returns (bytes32[] memory)
    {
        return _agentTasks[agentId];
    }

    function getClientTasks(address client)
        external view override returns (bytes32[] memory)
    {
        return _clientTasks[client];
    }

    // ============================================================
    //                     INTERNAL HELPERS
    // ============================================================

    function _getAgentProfile(uint256 agentId)
        internal view returns (IAgentRegistry.AgentProfile memory)
    {
        return IAgentRegistry(registry).getAgent(agentId);
    }

    function _getAgentScore(uint256 agentId) internal view returns (uint256) {
        try IReputationOracle(reputationOracle).getScore(agentId) returns (uint256 score) {
            return score;
        } catch {
            return 5000; // Default to neutral if oracle not initialized
        }
    }

    function _updateAgentReputation(
        uint256 agentId,
        IReputationOracle.UpdateReason reason,
        bytes32 taskId
    ) internal {
        try IReputationOracle(reputationOracle).updateReputation(agentId, reason, taskId) {}
        catch {} // Don't revert if oracle update fails
    }
}
