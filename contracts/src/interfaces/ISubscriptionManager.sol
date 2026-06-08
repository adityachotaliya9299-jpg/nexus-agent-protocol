// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISubscriptionManager
/// @author Aditya Chotaliya [adityachotaliya.vercel.app]
/// @notice Interface for the recurring payment subscription system
/// @dev Enables:
///      - Clients to subscribe to agents for recurring access/service
///      - Agents to offer tiered subscription plans (Basic/Pro/Enterprise)
///      - Automatic recurring payments (triggered by keeper or agent)
///      - Agent-to-agent subscriptions (hiring sub-agents on retainer)
///      - Grace periods, pausing, and cancellation with refunds
///
/// Subscription lifecycle:
///   ACTIVE → PAUSED → ACTIVE     (owner can pause/resume)
///   ACTIVE → CANCELLED           (either party cancels)
///   ACTIVE → EXPIRED             (payment failed + grace period passed)
///   ACTIVE → PAST_DUE            (payment due, not yet collected)
interface ISubscriptionManager {
    // ============================================================
    //                         ENUMS
    // ============================================================

    enum SubscriptionStatus {
        ACTIVE,      // Payments flowing, service active
        PAUSED,      // Temporarily suspended by subscriber
        PAST_DUE,    // Payment missed, in grace period
        CANCELLED,   // Terminated, no refund
        EXPIRED      // Grace period passed without payment
    }

    enum PlanTier {
        BASIC,       // Entry level access
        PRO,         // Standard tier
        ENTERPRISE   // Full access
    }

    // ============================================================
    //                         STRUCTS
    // ============================================================

    struct Plan {
        bytes32 planId;
        uint256 agentId;         // Which agent offers this plan
        PlanTier tier;
        string metadataURI;      // IPFS: plan description, features
        uint256 pricePerPeriod;  // ETH per billing period
        uint256 periodDuration;  // Seconds per billing period (e.g. 30 days)
        uint256 maxSubscribers;  // 0 = unlimited
        uint256 currentSubscribers;
        bool isActive;           // Agent can deactivate plans
        uint256 createdAt;
    }

    struct Subscription {
        bytes32 subscriptionId;
        bytes32 planId;
        uint256 agentId;         // Agent being subscribed to
        address subscriber;      // Who is paying
        uint256 subscriberAgentId; // If subscriber is an agent (0 = human)
        SubscriptionStatus status;
        uint256 startedAt;
        uint256 nextPaymentDue;
        uint256 lastPaymentAt;
        uint256 totalPaid;
        uint256 paymentsCount;
        uint256 gracePeriodEnd;  // 0 if not in grace period
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event PlanCreated(
        bytes32 indexed planId,
        uint256 indexed agentId,
        PlanTier tier,
        uint256 pricePerPeriod,
        uint256 periodDuration
    );

    event PlanUpdated(bytes32 indexed planId, uint256 newPrice, bool isActive);

    event SubscriptionCreated(
        bytes32 indexed subscriptionId,
        bytes32 indexed planId,
        address indexed subscriber,
        uint256 agentId
    );

    event PaymentProcessed(
        bytes32 indexed subscriptionId,
        uint256 amount,
        uint256 nextPaymentDue
    );

    event SubscriptionPaused(bytes32 indexed subscriptionId, address pausedBy);

    event SubscriptionResumed(bytes32 indexed subscriptionId);

    event SubscriptionCancelled(bytes32 indexed subscriptionId, address cancelledBy);

    event SubscriptionExpired(bytes32 indexed subscriptionId);

    event SubscriptionPastDue(bytes32 indexed subscriptionId, uint256 gracePeriodEnd);

    event GracePeriodUpdated(uint256 newGracePeriod);

    event PlatformFeeUpdated(uint256 newFeeBps);

    // ============================================================
    //                         ERRORS
    // ============================================================

    error PlanNotFound(bytes32 planId);
    error PlanNotActive(bytes32 planId);
    error PlanFull(bytes32 planId);
    error SubscriptionNotFound(bytes32 subscriptionId);
    error SubscriptionNotActive(bytes32 subscriptionId);
    error SubscriptionAlreadyExists(address subscriber, bytes32 planId);
    error NotSubscriber(bytes32 subscriptionId, address caller);
    error NotAgentOwner(uint256 agentId, address caller);
    error InsufficientPayment(uint256 required, uint256 provided);
    error PaymentNotDue(bytes32 subscriptionId, uint256 dueAt);
    error AgentNotRegistered(uint256 agentId);
    error InvalidPeriodDuration();
    error InvalidPrice();
    error ZeroAddress();
    error NotAuthorized();
    error InvalidFee();

    // ============================================================
    //                     PLAN MANAGEMENT
    // ============================================================

    function createPlan(
        uint256 agentId,
        PlanTier tier,
        string calldata metadataURI,
        uint256 pricePerPeriod,
        uint256 periodDuration,
        uint256 maxSubscribers
    ) external returns (bytes32 planId);

    function updatePlan(bytes32 planId, uint256 newPrice, bool isActive) external;

    // ============================================================
    //                   SUBSCRIPTION LIFECYCLE
    // ============================================================

    function subscribe(bytes32 planId, uint256 subscriberAgentId)
        external payable returns (bytes32 subscriptionId);

    function processPayment(bytes32 subscriptionId) external payable;

    function pauseSubscription(bytes32 subscriptionId) external;

    function resumeSubscription(bytes32 subscriptionId) external payable;

    function cancelSubscription(bytes32 subscriptionId) external;

    function markExpired(bytes32 subscriptionId) external;

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    function getPlan(bytes32 planId) external view returns (Plan memory);

    function getSubscription(bytes32 subscriptionId)
        external view returns (Subscription memory);

    function getAgentPlans(uint256 agentId) external view returns (bytes32[] memory);

    function getSubscriberSubscriptions(address subscriber)
        external view returns (bytes32[] memory);

    function getAgentSubscriptions(uint256 agentId)
        external view returns (bytes32[] memory);

    function isSubscriptionActive(bytes32 subscriptionId) external view returns (bool);

    function isPaymentDue(bytes32 subscriptionId) external view returns (bool);

    function platformFeeBps() external view returns (uint256);

    function gracePeriod() external view returns (uint256);

    function totalSubscriptionsCreated() external view returns (uint256);

    function totalPaymentsProcessed() external view returns (uint256);
}
