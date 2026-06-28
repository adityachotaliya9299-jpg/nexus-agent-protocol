// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {SubscriptionManager} from "../src/subscriptions/SubscriptionManager.sol";
import {ISubscriptionManager} from "../src/interfaces/ISubscriptionManager.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";

/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Mock agent wallet that receives ETH
contract MockWallet {
    uint256 public totalReceived;
    receive() external payable { totalReceived += msg.value; }
}

contract SubscriptionManagerTest is Test {
    // ============================================================
    //                         SETUP
    // ============================================================

    SubscriptionManager public manager;
    AgentRegistry public registry;

    MockWallet public agentWallet1;
    MockWallet public agentWallet2;

    address public protocolOwner = makeAddr("protocolOwner");
    address public agentOwner    = makeAddr("agentOwner");
    address public agentOwner2   = makeAddr("agentOwner2");
    address public subscriber    = makeAddr("subscriber");
    address public subscriber2   = makeAddr("subscriber2");
    address public stranger      = makeAddr("stranger");

    uint256 constant AGENT_ID_1     = 1;
    uint256 constant AGENT_ID_2     = 2;
    uint256 constant PRICE          = 0.1 ether;
    uint256 constant PERIOD         = 30 days;
    uint256 constant PLATFORM_FEE   = 250; // 2.5%

    string constant PLAN_META = "ipfs://QmPlanMeta";
    string constant META      = "ipfs://QmAgentMeta";

    bytes32 public planId; // Basic plan created in setUp

    function setUp() public {
        agentWallet1 = new MockWallet();
        agentWallet2 = new MockWallet();

        registry = new AgentRegistry(protocolOwner);

        vm.prank(agentOwner);
        registry.registerAgent(META, IAgentRegistry.AgentCategory.CODE);

        vm.prank(agentOwner2);
        registry.registerAgent(META, IAgentRegistry.AgentCategory.TRADING);

        vm.prank(agentOwner);
        registry.setAgentWallet(AGENT_ID_1, address(agentWallet1));

        vm.prank(agentOwner2);
        registry.setAgentWallet(AGENT_ID_2, address(agentWallet2));

        manager = new SubscriptionManager(protocolOwner, address(registry), PLATFORM_FEE);

        // Create a default Basic plan for agent 1
        vm.prank(agentOwner);
        planId = manager.createPlan(
            AGENT_ID_1,
            ISubscriptionManager.PlanTier.BASIC,
            PLAN_META,
            PRICE,
            PERIOD,
            10 // max 10 subscribers
        );

        vm.deal(subscriber, 100 ether);
        vm.deal(subscriber2, 100 ether);
        vm.deal(agentOwner, 100 ether);
    }

    // ============================================================
    //                    HELPERS
    // ============================================================

    function _subscribe() internal returns (bytes32 subId) {
        vm.prank(subscriber);
        subId = manager.subscribe{value: PRICE}(planId, 0);
    }

    function _subscribeAndWarp() internal returns (bytes32 subId) {
        subId = _subscribe();
        vm.warp(block.timestamp + PERIOD + 1); // move to next billing period
    }

    // ============================================================
    //           DEPLOYMENT TESTS (4 tests)
    // ============================================================

    function test_Deploy_CorrectState() public view {
        assertEq(manager.protocolOwner(), protocolOwner);
        assertEq(manager.registry(), address(registry));
        assertEq(manager.platformFeeBps(), PLATFORM_FEE);
        assertEq(manager.gracePeriod(), manager.DEFAULT_GRACE_PERIOD());
        assertEq(manager.totalSubscriptionsCreated(), 0);
        assertEq(manager.totalPaymentsProcessed(), 0);
    }

    function test_Deploy_Revert_ZeroOwner() public {
        vm.expectRevert(ISubscriptionManager.ZeroAddress.selector);
        new SubscriptionManager(address(0), address(registry), PLATFORM_FEE);
    }

    function test_Deploy_Revert_ZeroRegistry() public {
        vm.expectRevert(ISubscriptionManager.ZeroAddress.selector);
        new SubscriptionManager(protocolOwner, address(0), PLATFORM_FEE);
    }

    function test_Deploy_Revert_FeeTooHigh() public {
        vm.expectRevert(ISubscriptionManager.InvalidFee.selector);
        new SubscriptionManager(protocolOwner, address(registry), 1001);
    }

    // ============================================================
    //           PLAN CREATION TESTS (7 tests)
    // ============================================================

    function test_CreatePlan_Success() public view {
        ISubscriptionManager.Plan memory plan = manager.getPlan(planId);
        assertEq(plan.agentId, AGENT_ID_1);
        assertEq(plan.pricePerPeriod, PRICE);
        assertEq(plan.periodDuration, PERIOD);
        assertEq(uint256(plan.tier), uint256(ISubscriptionManager.PlanTier.BASIC));
        assertTrue(plan.isActive);
        assertEq(plan.maxSubscribers, 10);
        assertEq(plan.currentSubscribers, 0);
    }

    function test_CreatePlan_EmitsEvent() public {
        vm.expectEmit(false, true, false, true);
        emit ISubscriptionManager.PlanCreated(
            bytes32(0), AGENT_ID_1, ISubscriptionManager.PlanTier.PRO, PRICE, PERIOD
        );
        vm.prank(agentOwner);
        manager.createPlan(AGENT_ID_1, ISubscriptionManager.PlanTier.PRO, PLAN_META, PRICE, PERIOD, 0);
    }

    function test_CreatePlan_TracksAgentPlans() public {
        vm.prank(agentOwner);
        manager.createPlan(AGENT_ID_1, ISubscriptionManager.PlanTier.PRO, PLAN_META, PRICE * 2, PERIOD, 0);

        bytes32[] memory plans = manager.getAgentPlans(AGENT_ID_1);
        assertEq(plans.length, 2); // setUp created 1, now 2
    }

    function test_CreatePlan_Revert_NotAgentOwner() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(ISubscriptionManager.NotAgentOwner.selector, AGENT_ID_1, stranger)
        );
        manager.createPlan(AGENT_ID_1, ISubscriptionManager.PlanTier.BASIC, PLAN_META, PRICE, PERIOD, 0);
    }

    function test_CreatePlan_Revert_ZeroPrice() public {
        vm.prank(agentOwner);
        vm.expectRevert(ISubscriptionManager.InvalidPrice.selector);
        manager.createPlan(AGENT_ID_1, ISubscriptionManager.PlanTier.BASIC, PLAN_META, 0, PERIOD, 0);
    }

    function test_CreatePlan_Revert_PeriodTooShort() public {
        vm.prank(agentOwner);
        vm.expectRevert(ISubscriptionManager.InvalidPeriodDuration.selector);
        manager.createPlan(AGENT_ID_1, ISubscriptionManager.PlanTier.BASIC, PLAN_META, PRICE, 1 hours, 0);
    }

    function test_CreatePlan_Revert_PeriodTooLong() public {
        vm.prank(agentOwner);
        vm.expectRevert(ISubscriptionManager.InvalidPeriodDuration.selector);
        manager.createPlan(AGENT_ID_1, ISubscriptionManager.PlanTier.BASIC, PLAN_META, PRICE, 366 days, 0);
    }

    // ============================================================
    //           UPDATE PLAN TESTS (4 tests)
    // ============================================================

    function test_UpdatePlan_Success() public {
        vm.prank(agentOwner);
        manager.updatePlan(planId, PRICE * 2, true);

        ISubscriptionManager.Plan memory plan = manager.getPlan(planId);
        assertEq(plan.pricePerPeriod, PRICE * 2);
        assertTrue(plan.isActive);
    }

    function test_UpdatePlan_Deactivate() public {
        vm.prank(agentOwner);
        manager.updatePlan(planId, PRICE, false);

        assertFalse(manager.getPlan(planId).isActive);
    }

    function test_UpdatePlan_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit ISubscriptionManager.PlanUpdated(planId, PRICE * 2, true);
        vm.prank(agentOwner);
        manager.updatePlan(planId, PRICE * 2, true);
    }

    function test_UpdatePlan_Revert_NotOwner() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(ISubscriptionManager.NotAgentOwner.selector, AGENT_ID_1, stranger)
        );
        manager.updatePlan(planId, PRICE, true);
    }

    // ============================================================
    //           SUBSCRIBE TESTS (9 tests)
    // ============================================================

    function test_Subscribe_Success() public {
        bytes32 subId = _subscribe();

        ISubscriptionManager.Subscription memory sub = manager.getSubscription(subId);
        assertEq(sub.subscriber, subscriber);
        assertEq(sub.agentId, AGENT_ID_1);
        assertEq(uint256(sub.status), uint256(ISubscriptionManager.SubscriptionStatus.ACTIVE));
        assertEq(sub.totalPaid, PRICE);
        assertEq(sub.paymentsCount, 1);
        assertEq(manager.totalSubscriptionsCreated(), 1);
        assertEq(manager.totalPaymentsProcessed(), 1);
    }

    function test_Subscribe_FirstPaymentGoesToAgent() public {
        uint256 expectedFee = (PRICE * PLATFORM_FEE) / 10000;
        uint256 expectedAgentPayment = PRICE - expectedFee;

        _subscribe();

        assertEq(address(agentWallet1).balance, expectedAgentPayment);
        assertEq(manager.accumulatedFees(), expectedFee);
    }

    function test_Subscribe_EmitsEvent() public {
        vm.expectEmit(false, true, true, false);
        emit ISubscriptionManager.SubscriptionCreated(bytes32(0), planId, subscriber, AGENT_ID_1);
        vm.prank(subscriber);
        manager.subscribe{value: PRICE}(planId, 0);
    }

    function test_Subscribe_SetsNextPaymentDue() public {
        bytes32 subId = _subscribe();
        ISubscriptionManager.Subscription memory sub = manager.getSubscription(subId);
        assertEq(sub.nextPaymentDue, block.timestamp + PERIOD);
    }

    function test_Subscribe_TracksSubscriberSubs() public {
        bytes32 subId = _subscribe();
        bytes32[] memory subs = manager.getSubscriberSubscriptions(subscriber);
        assertEq(subs.length, 1);
        assertEq(subs[0], subId);
    }

    function test_Subscribe_IncrementsCurrentSubscribers() public {
        _subscribe();
        assertEq(manager.getPlan(planId).currentSubscribers, 1);
    }

    function test_Subscribe_Revert_InsufficientPayment() public {
        vm.prank(subscriber);
        vm.expectRevert(
            abi.encodeWithSelector(ISubscriptionManager.InsufficientPayment.selector, PRICE, PRICE / 2)
        );
        manager.subscribe{value: PRICE / 2}(planId, 0);
    }

    function test_Subscribe_Revert_PlanNotActive() public {
        vm.prank(agentOwner);
        manager.updatePlan(planId, PRICE, false);

        vm.prank(subscriber);
        vm.expectRevert(
            abi.encodeWithSelector(ISubscriptionManager.PlanNotActive.selector, planId)
        );
        manager.subscribe{value: PRICE}(planId, 0);
    }

    function test_Subscribe_Revert_PlanFull() public {
        // Create a plan with max 1 subscriber
        vm.prank(agentOwner);
        bytes32 limitedPlan = manager.createPlan(
            AGENT_ID_1, ISubscriptionManager.PlanTier.PRO, PLAN_META, PRICE, PERIOD, 1
        );

        vm.prank(subscriber);
        manager.subscribe{value: PRICE}(limitedPlan, 0);

        vm.prank(subscriber2);
        vm.expectRevert(
            abi.encodeWithSelector(ISubscriptionManager.PlanFull.selector, limitedPlan)
        );
        manager.subscribe{value: PRICE}(limitedPlan, 0);
    }

    // ============================================================
    //           PROCESS PAYMENT TESTS (7 tests)
    // ============================================================

    function test_ProcessPayment_Success() public {
        bytes32 subId = _subscribeAndWarp();

        vm.prank(subscriber);
        manager.processPayment{value: PRICE}(subId);

        ISubscriptionManager.Subscription memory sub = manager.getSubscription(subId);
        assertEq(sub.paymentsCount, 2);
        assertEq(sub.totalPaid, PRICE * 2);
        assertEq(uint256(sub.status), uint256(ISubscriptionManager.SubscriptionStatus.ACTIVE));
        assertEq(manager.totalPaymentsProcessed(), 2);
    }

    function test_ProcessPayment_EmitsEvent() public {
        bytes32 subId = _subscribeAndWarp();
        uint256 expectedNext = block.timestamp + PERIOD;

        vm.expectEmit(true, false, false, true);
        emit ISubscriptionManager.PaymentProcessed(subId, PRICE, expectedNext);
        vm.prank(subscriber);
        manager.processPayment{value: PRICE}(subId);
    }

    function test_ProcessPayment_AgentReceivesETH() public {
        bytes32 subId = _subscribeAndWarp();
        uint256 walletBefore = address(agentWallet1).balance;

        vm.prank(subscriber);
        manager.processPayment{value: PRICE}(subId);

        uint256 expectedFee = (PRICE * PLATFORM_FEE) / 10000;
        assertEq(address(agentWallet1).balance - walletBefore, PRICE - expectedFee);
    }

    function test_ProcessPayment_Revert_NotDueYet() public {
        bytes32 subId = _subscribe();

        vm.prank(subscriber);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISubscriptionManager.PaymentNotDue.selector,
                subId,
                block.timestamp + PERIOD
            )
        );
        manager.processPayment{value: PRICE}(subId);
    }

    function test_ProcessPayment_Revert_Cancelled() public {
        bytes32 subId = _subscribe();

        vm.prank(subscriber);
        manager.cancelSubscription(subId);

        vm.warp(block.timestamp + PERIOD + 1);

        vm.prank(subscriber);
        vm.expectRevert(
            abi.encodeWithSelector(ISubscriptionManager.SubscriptionNotActive.selector, subId)
        );
        manager.processPayment{value: PRICE}(subId);
    }

    function test_ProcessPayment_Revert_InsufficientAmount() public {
        bytes32 subId = _subscribeAndWarp();

        vm.prank(subscriber);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISubscriptionManager.InsufficientPayment.selector, PRICE, PRICE / 2
            )
        );
        manager.processPayment{value: PRICE / 2}(subId);
    }

    function test_ProcessPayment_AnyoneCanPay() public {
        bytes32 subId = _subscribeAndWarp();

        // Stranger pays on behalf of subscriber (keeper pattern)
        vm.deal(stranger, 10 ether);
        vm.prank(stranger);
        manager.processPayment{value: PRICE}(subId);

        assertEq(manager.getSubscription(subId).paymentsCount, 2);
    }

    // ============================================================
    //           PAUSE / RESUME TESTS (6 tests)
    // ============================================================

    function test_PauseSubscription_Success() public {
        bytes32 subId = _subscribe();

        vm.prank(subscriber);
        manager.pauseSubscription(subId);

        assertEq(
            uint256(manager.getSubscription(subId).status),
            uint256(ISubscriptionManager.SubscriptionStatus.PAUSED)
        );
    }

    function test_PauseSubscription_EmitsEvent() public {
        bytes32 subId = _subscribe();

        vm.expectEmit(true, false, false, true);
        emit ISubscriptionManager.SubscriptionPaused(subId, subscriber);
        vm.prank(subscriber);
        manager.pauseSubscription(subId);
    }

    function test_PauseSubscription_Revert_NotSubscriber() public {
        bytes32 subId = _subscribe();

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(ISubscriptionManager.NotSubscriber.selector, subId, stranger)
        );
        manager.pauseSubscription(subId);
    }

    function test_ResumeSubscription_NotOverdue() public {
        bytes32 subId = _subscribe();

        vm.prank(subscriber);
        manager.pauseSubscription(subId);

        vm.prank(subscriber);
        manager.resumeSubscription{value: 0}(subId);

        assertEq(
            uint256(manager.getSubscription(subId).status),
            uint256(ISubscriptionManager.SubscriptionStatus.ACTIVE)
        );
    }

    function test_ResumeSubscription_Overdue_RequiresPayment() public {
        bytes32 subId = _subscribe();
        vm.prank(subscriber);
        manager.pauseSubscription(subId);

        // Warp past payment due date
        vm.warp(block.timestamp + PERIOD + 1);

        vm.prank(subscriber);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISubscriptionManager.InsufficientPayment.selector, PRICE, 0
            )
        );
        manager.resumeSubscription{value: 0}(subId);
    }

    function test_ResumeSubscription_Overdue_WithPayment() public {
        bytes32 subId = _subscribe();
        vm.prank(subscriber);
        manager.pauseSubscription(subId);

        vm.warp(block.timestamp + PERIOD + 1);

        vm.prank(subscriber);
        manager.resumeSubscription{value: PRICE}(subId);

        assertEq(
            uint256(manager.getSubscription(subId).status),
            uint256(ISubscriptionManager.SubscriptionStatus.ACTIVE)
        );
    }

    // ============================================================
    //           CANCEL TESTS (4 tests)
    // ============================================================

    function test_CancelSubscription_BySubscriber() public {
        bytes32 subId = _subscribe();

        vm.prank(subscriber);
        manager.cancelSubscription(subId);

        assertEq(
            uint256(manager.getSubscription(subId).status),
            uint256(ISubscriptionManager.SubscriptionStatus.CANCELLED)
        );
    }

    function test_CancelSubscription_ByAgentOwner() public {
        bytes32 subId = _subscribe();

        vm.prank(agentOwner);
        manager.cancelSubscription(subId);

        assertEq(
            uint256(manager.getSubscription(subId).status),
            uint256(ISubscriptionManager.SubscriptionStatus.CANCELLED)
        );
    }

    function test_CancelSubscription_DecrementsSubscribers() public {
        bytes32 subId = _subscribe();
        assertEq(manager.getPlan(planId).currentSubscribers, 1);

        vm.prank(subscriber);
        manager.cancelSubscription(subId);
        assertEq(manager.getPlan(planId).currentSubscribers, 0);
    }

    function test_CancelSubscription_Revert_NotAuthorized() public {
        bytes32 subId = _subscribe();

        vm.prank(stranger);
        vm.expectRevert("Not subscriber or agent owner");
        manager.cancelSubscription(subId);
    }

    // ============================================================
    //           EXPIRY TESTS (3 tests)
    // ============================================================

    function test_MarkExpired_SetsPastDue_First() public {
        bytes32 subId = _subscribeAndWarp();

        manager.markExpired(subId);

        assertEq(
            uint256(manager.getSubscription(subId).status),
            uint256(ISubscriptionManager.SubscriptionStatus.PAST_DUE)
        );
    }

    function test_MarkExpired_AfterGracePeriod_Expires() public {
        bytes32 subId = _subscribeAndWarp();

        manager.markExpired(subId); // sets PAST_DUE + gracePeriodEnd

        vm.warp(block.timestamp + manager.gracePeriod() + 1);

        manager.markExpired(subId);

        assertEq(
            uint256(manager.getSubscription(subId).status),
            uint256(ISubscriptionManager.SubscriptionStatus.EXPIRED)
        );
    }

    function test_MarkExpired_DecrementsSubscriberCount() public {
        bytes32 subId = _subscribeAndWarp();
        assertEq(manager.getPlan(planId).currentSubscribers, 1);

        manager.markExpired(subId);
        vm.warp(block.timestamp + manager.gracePeriod() + 1);
        manager.markExpired(subId);

        assertEq(manager.getPlan(planId).currentSubscribers, 0);
    }

    // ============================================================
    //           ADMIN TESTS (4 tests)
    // ============================================================

    function test_SetPlatformFee_Success() public {
        vm.prank(protocolOwner);
        manager.setPlatformFee(500);
        assertEq(manager.platformFeeBps(), 500);
    }

    function test_SetPlatformFee_Revert_TooHigh() public {
        vm.prank(protocolOwner);
        vm.expectRevert(ISubscriptionManager.InvalidFee.selector);
        manager.setPlatformFee(1001);
    }

    function test_SetGracePeriod_Success() public {
        vm.prank(protocolOwner);
        manager.setGracePeriod(7 days);
        assertEq(manager.gracePeriod(), 7 days);
    }

    function test_WithdrawFees_Success() public {
        _subscribe(); // generates fees
        uint256 fees = manager.accumulatedFees();
        assertGt(fees, 0);

        address payable treasury = payable(makeAddr("treasury"));
        vm.prank(protocolOwner);
        manager.withdrawFees(treasury);

        assertEq(manager.accumulatedFees(), 0);
        assertEq(treasury.balance, fees);
    }

    // ============================================================
    //           INTEGRATION TESTS (5 tests)
    // ============================================================

    function test_Integration_AgentToAgentSubscription() public {
        // Agent 2 subscribes to agent 1 on retainer
        vm.deal(agentOwner2, 10 ether);
        vm.prank(agentOwner2);
        bytes32 subId = manager.subscribe{value: PRICE}(planId, AGENT_ID_2);

        ISubscriptionManager.Subscription memory sub = manager.getSubscription(subId);
        assertEq(sub.subscriber, agentOwner2);
        assertEq(sub.subscriberAgentId, AGENT_ID_2);
        assertEq(sub.agentId, AGENT_ID_1);
    }

    function test_Integration_MultipleRecurringPayments() public {
        bytes32 subId = _subscribe();

        for (uint256 i = 0; i < 5; i++) {
            vm.warp(manager.getSubscription(subId).nextPaymentDue + 1);
            vm.prank(subscriber);
            manager.processPayment{value: PRICE}(subId);
        }

        ISubscriptionManager.Subscription memory sub = manager.getSubscription(subId);
        assertEq(sub.paymentsCount, 6); 
        assertEq(sub.totalPaid, PRICE * 6);
    }

    function test_Integration_MultipleSubscribersOnePlan() public {
        vm.prank(subscriber);
        manager.subscribe{value: PRICE}(planId, 0);

        vm.prank(subscriber2);
        manager.subscribe{value: PRICE}(planId, 0);

        assertEq(manager.getPlan(planId).currentSubscribers, 2);
        assertEq(manager.getAgentSubscriptions(AGENT_ID_1).length, 2);
    }

    function test_Integration_FeesAccumulateAcrossPayments() public {
        bytes32 subId = _subscribe();
        uint256 feePerPayment = (PRICE * PLATFORM_FEE) / 10000;

        vm.warp(block.timestamp + PERIOD + 1);
        vm.prank(subscriber);
        manager.processPayment{value: PRICE}(subId);

        assertEq(manager.accumulatedFees(), feePerPayment * 2); // 2 payments
    }

    function test_Integration_IsPaymentDue_Lifecycle() public {
        bytes32 subId = _subscribe();

        assertFalse(manager.isPaymentDue(subId)); // just subscribed

        vm.warp(block.timestamp + PERIOD + 1);
        assertTrue(manager.isPaymentDue(subId)); // period passed

        vm.prank(subscriber);
        manager.processPayment{value: PRICE}(subId);
        assertFalse(manager.isPaymentDue(subId)); // just paid
    }

    // ============================================================
    //                   FUZZ TESTS (4 tests)
    // ============================================================

    function testFuzz_Subscribe_PriceAlwaysTransferred(uint256 price) public {
        vm.assume(price > 0 && price <= 10 ether);
        vm.deal(subscriber, price + 1 ether);

        vm.prank(agentOwner);
        bytes32 fuzzPlanId = manager.createPlan(
            AGENT_ID_1, ISubscriptionManager.PlanTier.PRO, PLAN_META, price, PERIOD, 0
        );

        uint256 before = address(agentWallet1).balance;
        vm.prank(subscriber);
        manager.subscribe{value: price}(fuzzPlanId, 0);

        uint256 expectedFee = (price * PLATFORM_FEE) / 10000;
        assertEq(address(agentWallet1).balance - before, price - expectedFee);
    }

    function testFuzz_PlatformFee_AlwaysValid(uint256 fee) public {
        vm.assume(fee <= 1000);
        vm.prank(protocolOwner);
        manager.setPlatformFee(fee);
        assertEq(manager.platformFeeBps(), fee);
    }

    function testFuzz_PeriodDuration_ValidRange(uint256 period) public {
        vm.assume(period >= 1 days && period <= 365 days);

        vm.prank(agentOwner);
        bytes32 pid = manager.createPlan(
            AGENT_ID_1, ISubscriptionManager.PlanTier.BASIC, PLAN_META, PRICE, period, 0
        );

        assertEq(manager.getPlan(pid).periodDuration, period);
    }

    function testFuzz_SubscriptionId_AlwaysUnique(uint8 count) public {
        vm.assume(count > 1 && count <= 10);

        // Create enough subscribers
        bytes32[] memory ids = new bytes32[](count);
        for (uint256 i = 0; i < count; i++) {
            address sub = makeAddr(string(abi.encodePacked("sub", i)));
            vm.deal(sub, 10 ether);
            vm.prank(sub);
            ids[i] = manager.subscribe{value: PRICE}(planId, 0);
        }

        for (uint256 i = 0; i < count; i++) {
            for (uint256 j = i + 1; j < count; j++) {
                assertTrue(ids[i] != ids[j], "Duplicate subscriptionId");
            }
        }
    }
}
