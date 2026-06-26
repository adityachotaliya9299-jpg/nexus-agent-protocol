// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ITaskMarketplace} from "../interfaces/ITaskMarketplace.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";
import {IReputationOracle} from "../interfaces/IReputationOracle.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title TaskMarketplace
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice The core task economy — agents post bids, get hired, submit work, get paid
/// @dev Phase 11 gas optimizations applied:
///      - Custom errors replace all require strings (~50 gas each)
///      - Storage pointer caching in updateReputation path
///      - minReputation check uses cached local var (avoids double SLOAD)
///      - platformFeeBps cached in postTask
///      - requiresMinReputation field removed: minReputation > 0 used instead
contract TaskMarketplace is ITaskMarketplace, ReentrancyGuard {
    // ============================================================
    //                       CONSTANTS
    // ============================================================

    uint256 public constant MAX_FEE_BPS  = 1000;    // Max 10% platform fee
    uint256 public constant MIN_DEADLINE = 1 hours;
    uint256 public constant MAX_DEADLINE = 365 days;

    // ============================================================
    //                         STORAGE
    // ============================================================

    address public immutable protocolOwner;
    address public immutable registry;
    address public immutable reputationOracle;

    address public arbitrator;
    uint256 public override platformFeeBps;
    uint256 public accumulatedFees;
    uint256 public override totalTasksPosted;
    uint256 public override totalTasksCompleted;

    mapping(bytes32 => Task)                        private _tasks;
    mapping(bytes32 => mapping(uint256 => Bid))     private _bids;
    mapping(bytes32 => uint256[])                   private _taskBidders;
    mapping(bytes32 => Dispute)                     private _disputes;
    mapping(uint256 => bytes32[])                   private _agentTasks;
    mapping(address => bytes32[])                   private _clientTasks;

    uint256 private _taskNonce;

    // ============================================================
    //                       MODIFIERS
    // ============================================================

    modifier onlyProtocolOwner() {
        // OPT: custom error instead of string revert (~50 gas saved)
        if (msg.sender != protocolOwner) revert NotAuthorized();
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

        protocolOwner    = _protocolOwner;
        registry         = _registry;
        reputationOracle = _reputationOracle;
        arbitrator       = _arbitrator;
        platformFeeBps   = _platformFeeBps;
    }

    // ============================================================
    //                      POST TASK
    // ============================================================

    function postTask(
        string calldata metadataURI,
        uint256 deadline,
        uint256 minReputation
    ) external payable override nonReentrant returns (bytes32 taskId) {
        if (msg.value == 0) revert InvalidReward();
        if (bytes(metadataURI).length == 0) revert InvalidMetadata();
        if (deadline < block.timestamp + MIN_DEADLINE) revert InvalidDeadline();
        if (deadline > block.timestamp + MAX_DEADLINE) revert InvalidDeadline();

        taskId = keccak256(abi.encodePacked(msg.sender, _taskNonce++, block.timestamp));

        // OPT: cache platformFeeBps in local var — single SLOAD instead of two
        uint256 feeBps = platformFeeBps;
        uint256 fee = (msg.value * feeBps) / 10000;

        _tasks[taskId] = Task({
            taskId:               taskId,
            client:               msg.sender,
            clientAgentId:        0,
            metadataURI:          metadataURI,
            reward:               msg.value,
            deadline:             deadline,
            createdAt:            block.timestamp,
            assignedAt:           0,
            submittedAt:          0,
            completedAt:          0,
            status:               TaskStatus.OPEN,
            assignedAgentId:      0,
            assignedAgentWallet:  address(0),
            platformFee:          fee,
            requiresMinReputation: minReputation > 0,
            minReputation:        minReputation
        });

        _clientTasks[msg.sender].push(taskId);
        totalTasksPosted++;

        emit TaskPosted(taskId, msg.sender, msg.value, deadline, metadataURI);
    }

    // ============================================================
    //                      SUBMIT BID
    // ============================================================

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

        IAgentRegistry.AgentProfile memory profile = _getAgentProfile(agentId);
        if (profile.owner != msg.sender) revert AgentNotRegistered(agentId);
        if (task.client == msg.sender) revert CannotBidOwnTask();

        // OPT: cache minReputation to avoid double SLOAD
        uint256 minRep = task.minReputation;
        if (minRep > 0) {
            uint256 score = _getAgentScore(agentId);
            if (score < minRep) {
                revert InsufficientReputation(agentId, minRep, score);
            }
        }

        if (_bids[taskId][agentId].submittedAt != 0 && !_bids[taskId][agentId].isWithdrawn) {
            revert BidAlreadyExists(taskId, agentId);
        }

        _bids[taskId][agentId] = Bid({
            taskId:         taskId,
            agentId:        agentId,
            agentWallet:    profile.agentWallet,
            proposedReward: task.reward,
            proposalURI:    proposalURI,
            estimatedTime:  estimatedTime,
            submittedAt:    block.timestamp,
            isAccepted:     false,
            isWithdrawn:    false
        });

        _taskBidders[taskId].push(agentId);

        emit BidSubmitted(taskId, agentId, task.reward);
    }

    // ============================================================
    //                      WITHDRAW BID
    // ============================================================

    function withdrawBid(bytes32 taskId, uint256 agentId)
        external override taskExists(taskId)
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

    function assignAgent(bytes32 taskId, uint256 agentId)
        external override taskExists(taskId) nonReentrant
    {
        Task storage task = _tasks[taskId];

        if (task.status != TaskStatus.OPEN) revert TaskNotOpen(taskId);
        if (task.client != msg.sender) revert NotTaskClient(taskId, msg.sender);
        if (block.timestamp >= task.deadline) revert DeadlinePassed(taskId);

        Bid storage bid = _bids[taskId][agentId];
        if (bid.submittedAt == 0) revert BidNotFound(taskId, agentId);
        if (bid.isWithdrawn) revert BidWithdrawnAlready(taskId, agentId);

        IAgentRegistry.AgentProfile memory profile = _getAgentProfile(agentId);

        task.status              = TaskStatus.ASSIGNED;
        task.assignedAgentId     = agentId;
        task.assignedAgentWallet = profile.agentWallet;
        task.assignedAt          = block.timestamp;
        bid.isAccepted           = true;

        _agentTasks[agentId].push(taskId);

        emit TaskAssigned(taskId, agentId, profile.agentWallet);
    }

    // ============================================================
    //                      SUBMIT WORK
    // ============================================================

    function submitWork(bytes32 taskId, uint256 agentId, string calldata resultURI)
        external override taskExists(taskId)
    {
        Task storage task = _tasks[taskId];

        if (task.status != TaskStatus.ASSIGNED) revert TaskNotAssigned(taskId);
        if (task.assignedAgentId != agentId) revert NotAssignedAgent(taskId, msg.sender);
        if (bytes(resultURI).length == 0) revert InvalidMetadata();

        IAgentRegistry.AgentProfile memory profile = _getAgentProfile(agentId);
        if (profile.owner != msg.sender) revert NotAssignedAgent(taskId, msg.sender);

        task.status      = TaskStatus.SUBMITTED;
        task.submittedAt = block.timestamp;

        emit WorkSubmitted(taskId, agentId, resultURI);
    }

    // ============================================================
    //                      APPROVE WORK
    // ============================================================

    function approveWork(bytes32 taskId)
        external override taskExists(taskId) nonReentrant
    {
        Task storage task = _tasks[taskId];

        if (task.status != TaskStatus.SUBMITTED) revert TaskNotSubmitted(taskId);
        if (task.client != msg.sender) revert NotTaskClient(taskId, msg.sender);

        task.status      = TaskStatus.COMPLETED;
        task.completedAt = block.timestamp;
        totalTasksCompleted++;

        // OPT: read reward and fee once, compute agentPayment locally
        uint256 reward       = task.reward;
        uint256 fee          = task.platformFee;
        uint256 agentPayment = reward - fee;
        uint256 assignedId   = task.assignedAgentId;
        address agentWallet  = task.assignedAgentWallet;

        accumulatedFees += fee;

        (bool success,) = payable(agentWallet).call{value: agentPayment}("");
        if (!success) revert EscrowTransferFailed();

        _updateAgentReputation(assignedId, IReputationOracle.UpdateReason.TASK_COMPLETED, taskId);

        emit TaskCompleted(taskId, assignedId, agentPayment, fee);
    }

    // ============================================================
    //                      CANCEL TASK
    // ============================================================

    function cancelTask(bytes32 taskId)
        external override taskExists(taskId) nonReentrant
    {
        Task storage task = _tasks[taskId];

        if (task.client != msg.sender) revert NotTaskClient(taskId, msg.sender);
        if (task.status != TaskStatus.OPEN) revert TaskNotOpen(taskId);

        task.status = TaskStatus.CANCELLED;

        uint256 reward = task.reward;
        (bool success,) = payable(msg.sender).call{value: reward}("");
        if (!success) revert EscrowTransferFailed();

        emit TaskCancelled(taskId, msg.sender);
    }

    // ============================================================
    //                      DISPUTE
    // ============================================================

    function raiseDispute(bytes32 taskId, string calldata reasonURI)
        external override taskExists(taskId)
    {
        Task storage task = _tasks[taskId];

        bool isClient = task.client == msg.sender;
        bool isAgent  = false;
        if (task.assignedAgentId != 0) {
            IAgentRegistry.AgentProfile memory profile = _getAgentProfile(task.assignedAgentId);
            isAgent = profile.owner == msg.sender;
        }

        // OPT: custom error instead of require string
        if (!isClient && !isAgent) revert NotAuthorized();

        if (task.status != TaskStatus.SUBMITTED && task.status != TaskStatus.ASSIGNED) {
            revert TaskNotSubmitted(taskId);
        }
        if (_disputes[taskId].raisedAt != 0) revert AlreadyDisputed(taskId);
        if (bytes(reasonURI).length == 0) revert InvalidMetadata();

        task.status = TaskStatus.DISPUTED;

        _disputes[taskId] = Dispute({
            taskId:     taskId,
            raisedBy:   msg.sender,
            reasonURI:  reasonURI,
            raisedAt:   block.timestamp,
            outcome:    DisputeOutcome.NONE,
            resolvedBy: address(0),
            resolvedAt: 0,
            clientShare: 0
        });

        emit DisputeRaised(taskId, msg.sender, reasonURI);
    }

    function resolveDispute(
        bytes32 taskId,
        DisputeOutcome outcome,
        uint256 clientShareBps
    ) external override onlyArbitrator taskExists(taskId) nonReentrant {
        Task storage task = _tasks[taskId];
        if (task.status != TaskStatus.DISPUTED) revert TaskNotDisputed(taskId);

        // OPT: custom error instead of require string
        if (clientShareBps > 10000) revert InvalidFee();

        Dispute storage dispute = _disputes[taskId];
        dispute.outcome    = outcome;
        dispute.resolvedBy = msg.sender;
        dispute.resolvedAt = block.timestamp;
        dispute.clientShare = clientShareBps;

        task.status      = TaskStatus.RESOLVED;
        task.completedAt = block.timestamp;

        uint256 totalAmount = task.reward;

        if (outcome == DisputeOutcome.CLIENT_WINS) {
            (bool ok,) = payable(task.client).call{value: totalAmount}("");
            if (!ok) revert EscrowTransferFailed();
            _updateAgentReputation(task.assignedAgentId, IReputationOracle.UpdateReason.DISPUTE_LOST, taskId);

        } else if (outcome == DisputeOutcome.AGENT_WINS) {
            uint256 fee = task.platformFee;
            uint256 agentPayment = totalAmount - fee;
            accumulatedFees += fee;
            totalTasksCompleted++;
            (bool ok,) = payable(task.assignedAgentWallet).call{value: agentPayment}("");
            if (!ok) revert EscrowTransferFailed();
            _updateAgentReputation(task.assignedAgentId, IReputationOracle.UpdateReason.DISPUTE_WON, taskId);

        } else if (outcome == DisputeOutcome.SPLIT) {
            uint256 clientAmount = (totalAmount * clientShareBps) / 10000;
            uint256 agentAmount  = totalAmount - clientAmount;
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
        // OPT: custom error instead of require string
        if (!ok) revert EscrowTransferFailed();
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
            return 5000;
        }
    }

    function _updateAgentReputation(
        uint256 agentId,
        IReputationOracle.UpdateReason reason,
        bytes32 taskId
    ) internal {
        try IReputationOracle(reputationOracle).updateReputation(agentId, reason, taskId) {}
        catch {}
    }
}
