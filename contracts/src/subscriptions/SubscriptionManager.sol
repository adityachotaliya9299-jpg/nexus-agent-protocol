// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISubscriptionManager} from "../interfaces/ISubscriptionManager.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SubscriptionManager
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Recurring payment subscriptions for autonomous AI agent services
///
/// @dev Key design decisions:
///
///   PULL PAYMENTS:
///     Subscribers pre-authorize payments by depositing ETH when subscribing.
///     The agent (or a keeper) calls processPayment() each billing period.
///     This is safer than push payments (no ETH left in limbo).
///
///   GRACE PERIOD:
///     If payment is not collected within grace period (default: 3 days),
///     subscription moves to EXPIRED. Subscriber can resubscribe.
///
///   AGENT-TO-AGENT:
///     subscriberAgentId > 0 means an agent is subscribing to another agent.
///     Payment comes from the agent's wallet, enabling automated agent hiring.
///
///   FEE MODEL:
///     Platform takes platformFeeBps of each recurring payment.
///     Fees accumulate in contract, withdrawn by protocol owner.
///
///   PLAN VERSIONING:
///     Price changes only affect NEW subscriptions, not existing ones.
///     Existing subscribers keep their locked-in price until renewal.

contract SubscriptionManager is ISubscriptionManager, ReentrancyGuard {
    // ============================================================
    //                       CONSTANTS
    // ============================================================

    uint256 public constant MIN_PERIOD   = 1 days;
    uint256 public constant MAX_PERIOD   = 365 days;
    uint256 public constant MAX_FEE_BPS  = 1000;        // 10% max
    uint256 public constant DEFAULT_GRACE_PERIOD = 3 days;

    // ============================================================
    //                         STORAGE
    // ============================================================

    address public immutable protocolOwner;
    address public immutable registry;

    uint256 public override platformFeeBps;
    uint256 public override gracePeriod;
    uint256 public override totalSubscriptionsCreated;
    uint256 public override totalPaymentsProcessed;

    uint256 public accumulatedFees;

    /// @notice planId => Plan
    mapping(bytes32 => Plan) private _plans;

    /// @notice subscriptionId => Subscription
    mapping(bytes32 => Subscription) private _subscriptions;

    /// @notice agentId => list of planIds they offer
    mapping(uint256 => bytes32[]) private _agentPlans;

    /// @notice agentId => list of subscriptionIds for their plans
    mapping(uint256 => bytes32[]) private _agentSubscriptions;

    /// @notice subscriber address => list of subscriptionIds
    mapping(address => bytes32[]) private _subscriberSubscriptions;

    /// @notice subscriber + planId => subscriptionId (prevent duplicate active subs)
    mapping(address => mapping(bytes32 => bytes32)) private _activeSubByPlan;

    uint256 private _planNonce;
    uint256 private _subNonce;

    // ============================================================
    //                       MODIFIERS
    // ============================================================

    modifier onlyProtocolOwner() {
        if (msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    modifier planExists(bytes32 planId) {
        if (_plans[planId].createdAt == 0) revert PlanNotFound(planId);
        _;
    }

    modifier subExists(bytes32 subscriptionId) {
        if (_subscriptions[subscriptionId].startedAt == 0) {
            revert SubscriptionNotFound(subscriptionId);
        }
        _;
    }

    // ============================================================
    //                       CONSTRUCTOR
    // ============================================================

    constructor(
        address _protocolOwner,
        address _registry,
        uint256 _platformFeeBps
    ) {
        if (_protocolOwner == address(0) || _registry == address(0)) revert ZeroAddress();
        if (_platformFeeBps > MAX_FEE_BPS) revert InvalidFee();

        protocolOwner  = _protocolOwner;
        registry       = _registry;
        platformFeeBps = _platformFeeBps;
        gracePeriod    = DEFAULT_GRACE_PERIOD;
    }

    // ============================================================
    //                      PLAN MANAGEMENT
    // ============================================================

    /// @notice Agent creates a subscription plan
    function createPlan(
        uint256 agentId,
        PlanTier tier,
        string calldata metadataURI,
        uint256 pricePerPeriod,
        uint256 periodDuration,
        uint256 maxSubscribers
    ) external override returns (bytes32 planId) {
        if (pricePerPeriod == 0) revert InvalidPrice();
        if (periodDuration < MIN_PERIOD || periodDuration > MAX_PERIOD) {
            revert InvalidPeriodDuration();
        }

        // Verify agent exists and caller is owner
        IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(agentId);
        if (profile.owner != msg.sender) revert NotAgentOwner(agentId, msg.sender);

        planId = keccak256(abi.encodePacked(agentId, _planNonce++, block.timestamp));

        _plans[planId] = Plan({
            planId: planId,
            agentId: agentId,
            tier: tier,
            metadataURI: metadataURI,
            pricePerPeriod: pricePerPeriod,
            periodDuration: periodDuration,
            maxSubscribers: maxSubscribers,
            currentSubscribers: 0,
            isActive: true,
            createdAt: block.timestamp
        });

        _agentPlans[agentId].push(planId);

        emit PlanCreated(planId, agentId, tier, pricePerPeriod, periodDuration);
    }

    /// @notice Agent updates plan price or active status
    /// @dev Price changes only affect new subscribers
    function updatePlan(bytes32 planId, uint256 newPrice, bool isActive)
        external
        override
        planExists(planId)
    {
        Plan storage plan = _plans[planId];
        IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(plan.agentId);
        if (profile.owner != msg.sender) revert NotAgentOwner(plan.agentId, msg.sender);
        if (newPrice == 0) revert InvalidPrice();

        plan.pricePerPeriod = newPrice;
        plan.isActive = isActive;

        emit PlanUpdated(planId, newPrice, isActive);
    }

    // ============================================================
    //                      SUBSCRIBE
    // ============================================================

    /// @notice Subscribe to an agent plan — first payment sent with call
    /// @param planId The plan to subscribe to
    /// @param subscriberAgentId If subscriber is an agent (0 = human client)
    function subscribe(bytes32 planId, uint256 subscriberAgentId)
        external
        payable
        override
        planExists(planId)
        nonReentrant
        returns (bytes32 subscriptionId)
    {
        Plan storage plan = _plans[planId];
        if (!plan.isActive) revert PlanNotActive(planId);
        if (plan.maxSubscribers > 0 && plan.currentSubscribers >= plan.maxSubscribers) {
            revert PlanFull(planId);
        }

        // Check first payment covers at least one period
        uint256 required = plan.pricePerPeriod;
        if (msg.value < required) revert InsufficientPayment(required, msg.value);

        // No duplicate active subscriptions
        bytes32 existingSub = _activeSubByPlan[msg.sender][planId];
        if (existingSub != bytes32(0)) {
            Subscription storage existing = _subscriptions[existingSub];
            if (existing.status == SubscriptionStatus.ACTIVE ||
                existing.status == SubscriptionStatus.PAUSED) {
                revert SubscriptionAlreadyExists(msg.sender, planId);
            }
        }

        subscriptionId = keccak256(abi.encodePacked(msg.sender, planId, _subNonce++, block.timestamp));

        _subscriptions[subscriptionId] = Subscription({
            subscriptionId: subscriptionId,
            planId: planId,
            agentId: plan.agentId,
            subscriber: msg.sender,
            subscriberAgentId: subscriberAgentId,
            status: SubscriptionStatus.ACTIVE,
            startedAt: block.timestamp,
            nextPaymentDue: block.timestamp + plan.periodDuration,
            lastPaymentAt: block.timestamp,
            totalPaid: msg.value,
            paymentsCount: 1,
            gracePeriodEnd: 0
        });

        plan.currentSubscribers++;
        _activeSubByPlan[msg.sender][planId] = subscriptionId;
        _agentSubscriptions[plan.agentId].push(subscriptionId);
        _subscriberSubscriptions[msg.sender].push(subscriptionId);
        totalSubscriptionsCreated++;
        totalPaymentsProcessed++;

        // Transfer first payment to agent (minus fee)
        _transferPayment(plan.agentId, msg.value);

        emit SubscriptionCreated(subscriptionId, planId, msg.sender, plan.agentId);
        emit PaymentProcessed(subscriptionId, msg.value, block.timestamp + plan.periodDuration);
    }

    // ============================================================
    //                    PROCESS PAYMENT
    // ============================================================

    /// @notice Process a recurring payment for an active subscription
    /// @dev Can be called by the agent, a keeper, or the subscriber themselves
    function processPayment(bytes32 subscriptionId)
        external
        payable
        override
        subExists(subscriptionId)
        nonReentrant
    {
        Subscription storage sub = _subscriptions[subscriptionId];

        if (sub.status == SubscriptionStatus.CANCELLED ||
            sub.status == SubscriptionStatus.EXPIRED) {
            revert SubscriptionNotActive(subscriptionId);
        }

        if (block.timestamp < sub.nextPaymentDue) {
            revert PaymentNotDue(subscriptionId, sub.nextPaymentDue);
        }

        Plan storage plan = _plans[sub.planId];
        uint256 required = plan.pricePerPeriod;
        if (msg.value < required) revert InsufficientPayment(required, msg.value);

        // Update subscription state
        sub.status = SubscriptionStatus.ACTIVE;
        sub.nextPaymentDue = block.timestamp + plan.periodDuration;
        sub.lastPaymentAt = block.timestamp;
        sub.totalPaid += msg.value;
        sub.paymentsCount++;
        sub.gracePeriodEnd = 0;
        totalPaymentsProcessed++;

        // Transfer payment to agent
        _transferPayment(sub.agentId, msg.value);

        emit PaymentProcessed(subscriptionId, msg.value, sub.nextPaymentDue);
    }

    // ============================================================
    //                      PAUSE / RESUME
    // ============================================================

    function pauseSubscription(bytes32 subscriptionId)
        external
        override
        subExists(subscriptionId)
    {
        Subscription storage sub = _subscriptions[subscriptionId];
        if (sub.subscriber != msg.sender) revert NotSubscriber(subscriptionId, msg.sender);
        if (sub.status != SubscriptionStatus.ACTIVE) revert SubscriptionNotActive(subscriptionId);

        sub.status = SubscriptionStatus.PAUSED;
        emit SubscriptionPaused(subscriptionId, msg.sender);
    }

    /// @notice Resume a paused subscription — requires payment if overdue
    function resumeSubscription(bytes32 subscriptionId)
        external
        payable
        override
        subExists(subscriptionId)
        nonReentrant
    {
        Subscription storage sub = _subscriptions[subscriptionId];
        if (sub.subscriber != msg.sender) revert NotSubscriber(subscriptionId, msg.sender);
        if (sub.status != SubscriptionStatus.PAUSED) revert SubscriptionNotActive(subscriptionId);

        Plan storage plan = _plans[sub.planId];

        // If payment is overdue, require it to resume
        if (block.timestamp >= sub.nextPaymentDue) {
            if (msg.value < plan.pricePerPeriod) {
                revert InsufficientPayment(plan.pricePerPeriod, msg.value);
            }
            sub.nextPaymentDue = block.timestamp + plan.periodDuration;
            sub.lastPaymentAt = block.timestamp;
            sub.totalPaid += msg.value;
            sub.paymentsCount++;
            totalPaymentsProcessed++;
            _transferPayment(sub.agentId, msg.value);
            emit PaymentProcessed(subscriptionId, msg.value, sub.nextPaymentDue);
        }

        sub.status = SubscriptionStatus.ACTIVE;
        emit SubscriptionResumed(subscriptionId);
    }

    // ============================================================
    //                        CANCEL
    // ============================================================

    function cancelSubscription(bytes32 subscriptionId)
        external
        override
        subExists(subscriptionId)
    {
        Subscription storage sub = _subscriptions[subscriptionId];

        // Subscriber or agent owner can cancel
        bool isSubscriber = sub.subscriber == msg.sender;
        IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(sub.agentId);
        bool isAgentOwner = profile.owner == msg.sender;

        require(isSubscriber || isAgentOwner, "Not subscriber or agent owner");

        if (sub.status == SubscriptionStatus.CANCELLED) {
            revert SubscriptionNotActive(subscriptionId);
        }

        sub.status = SubscriptionStatus.CANCELLED;
        _plans[sub.planId].currentSubscribers--;

        emit SubscriptionCancelled(subscriptionId, msg.sender);
    }

    // ============================================================
    //                      MARK EXPIRED
    // ============================================================

    /// @notice Mark a subscription as expired after grace period
    /// @dev Anyone can call this — it's a state cleanup function
    function markExpired(bytes32 subscriptionId)
        external
        override
        subExists(subscriptionId)
    {
        Subscription storage sub = _subscriptions[subscriptionId];

        if (sub.status != SubscriptionStatus.ACTIVE &&
            sub.status != SubscriptionStatus.PAST_DUE) {
            revert SubscriptionNotActive(subscriptionId);
        }

        // Must be past due date
        require(block.timestamp >= sub.nextPaymentDue, "Not yet past due");

        if (sub.gracePeriodEnd == 0) {
            // First time: set grace period
            sub.status = SubscriptionStatus.PAST_DUE;
            sub.gracePeriodEnd = block.timestamp + gracePeriod;
            emit SubscriptionPastDue(subscriptionId, sub.gracePeriodEnd);
        } else if (block.timestamp > sub.gracePeriodEnd) {
            // Grace period passed: expire
            sub.status = SubscriptionStatus.EXPIRED;
            _plans[sub.planId].currentSubscribers--;
            emit SubscriptionExpired(subscriptionId);
        }
    }

    // ============================================================
    //                    ADMIN FUNCTIONS
    // ============================================================

    function setPlatformFee(uint256 newFeeBps) external onlyProtocolOwner {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(newFeeBps);
    }

    function setGracePeriod(uint256 newGracePeriod) external onlyProtocolOwner {
        gracePeriod = newGracePeriod;
        emit GracePeriodUpdated(newGracePeriod);
    }

    function withdrawFees(address payable to) external onlyProtocolOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accumulatedFees;
        accumulatedFees = 0;
        (bool ok,) = to.call{value: amount}("");
        require(ok, "Fee withdrawal failed");
    }

    // ============================================================
    //                     INTERNAL HELPERS
    // ============================================================

    function _transferPayment(uint256 agentId, uint256 amount) internal {
        uint256 fee = (amount * platformFeeBps) / 10000;
        uint256 agentAmount = amount - fee;
        accumulatedFees += fee;

        IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(agentId);
        address agentWallet = profile.agentWallet;

        if (agentWallet != address(0) && agentAmount > 0) {
            (bool ok,) = payable(agentWallet).call{value: agentAmount}("");
            require(ok, "Agent payment failed");
        }
    }

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    function getPlan(bytes32 planId) external view override returns (Plan memory) {
        if (_plans[planId].createdAt == 0) revert PlanNotFound(planId);
        return _plans[planId];
    }

    function getSubscription(bytes32 subscriptionId)
        external view override returns (Subscription memory)
    {
        if (_subscriptions[subscriptionId].startedAt == 0) {
            revert SubscriptionNotFound(subscriptionId);
        }
        return _subscriptions[subscriptionId];
    }

    function getAgentPlans(uint256 agentId)
        external view override returns (bytes32[] memory)
    {
        return _agentPlans[agentId];
    }

    function getSubscriberSubscriptions(address subscriber)
        external view override returns (bytes32[] memory)
    {
        return _subscriberSubscriptions[subscriber];
    }

    function getAgentSubscriptions(uint256 agentId)
        external view override returns (bytes32[] memory)
    {
        return _agentSubscriptions[agentId];
    }

    function isSubscriptionActive(bytes32 subscriptionId)
        external view override returns (bool)
    {
        return _subscriptions[subscriptionId].status == SubscriptionStatus.ACTIVE;
    }

    function isPaymentDue(bytes32 subscriptionId)
        external view override returns (bool)
    {
        Subscription storage sub = _subscriptions[subscriptionId];
        return sub.startedAt != 0 &&
            sub.status == SubscriptionStatus.ACTIVE &&
            block.timestamp >= sub.nextPaymentDue;
    }
}
