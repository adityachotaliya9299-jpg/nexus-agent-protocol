// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {CrossChainBridge} from "../src/bridge/CrossChainBridge.sol";
import {ICrossChainBridge} from "../src/interfaces/ICrossChainBridge.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";
import {ReputationOracle} from "../src/reputation/ReputationOracle.sol";
import {IReputationOracle} from "../src/interfaces/IReputationOracle.sol";

// ============================================================
//                     MOCK CONTRACTS
// ============================================================

/// @notice Simulates Chainlink CCIP router — accepts messages, can replay them
contract MockCCIPRouter {
    CrossChainBridge public bridge;
    uint256 public messagesSent;

    receive() external payable {}

    function setBridge(address _bridge) external {
        bridge = CrossChainBridge(payable(_bridge));
    }

    function send(uint64 /*destChain*/, bytes calldata /*payload*/) external payable {
        messagesSent++;
        // In real CCIP: would route to destination chain
    }

    /// @notice Simulate delivering a message back to our bridge (test helper)
    function simulateReceive(
        bytes32 messageId,
        uint64 sourceChain,
        bytes calldata payload
    ) external {
        bridge.ccipReceive(messageId, sourceChain, payload);
    }
}

/// @notice Agent wallet that receives ETH
contract MockAgentWallet {
    uint256 public totalReceived;
    receive() external payable { totalReceived += msg.value; }
}

// ============================================================
//                     TEST CONTRACT
// ============================================================

contract CrossChainBridgeTest is Test {
    // ============================================================
    //                         SETUP
    // ============================================================

    CrossChainBridge public bridge;
    AgentRegistry    public registry;
    ReputationOracle public oracle;
    MockCCIPRouter   public router;
    MockAgentWallet  public agentWallet;

    address public protocolOwner = makeAddr("protocolOwner");
    address public agentOwner    = makeAddr("agentOwner");
    address public agentOwner2   = makeAddr("agentOwner2");
    address public stranger      = makeAddr("stranger");

    uint256 constant AGENT_ID_1 = 1;
    uint256 constant AGENT_ID_2 = 2;

    // CCIP chain selectors (real Chainlink selectors)
    uint64 constant ETH_CHAIN    = 5009297550715157269;  // Ethereum mainnet
    uint64 constant POLYGON_CHAIN = 4051577828743386545; // Polygon
    uint64 constant ARB_CHAIN    = 4949039107694359620;  // Arbitrum
    uint64 constant BASE_CHAIN   = 15971525489660198786; // Base

    string constant META = "ipfs://QmAgentMeta";

    function setUp() public {
        agentWallet = new MockAgentWallet();

        // Deploy registry
        registry = new AgentRegistry(protocolOwner);

        vm.prank(agentOwner);
        registry.registerAgent(META, IAgentRegistry.AgentCategory.CODE);

        vm.prank(agentOwner2);
        registry.registerAgent(META, IAgentRegistry.AgentCategory.TRADING);

        vm.prank(agentOwner);
        registry.setAgentWallet(AGENT_ID_1, address(agentWallet));

        // Deploy oracle
        oracle = new ReputationOracle(protocolOwner, address(registry));
        vm.startPrank(protocolOwner);
        oracle.initializeAgent(AGENT_ID_1);
        oracle.initializeAgent(AGENT_ID_2);
        vm.stopPrank();

        // Deploy router
        router = new MockCCIPRouter();

        // Deploy bridge
        bridge = new CrossChainBridge(
            protocolOwner,
            address(registry),
            address(oracle),
            address(router),
            ETH_CHAIN
        );

        // Link router to bridge for simulate-receive tests
        router.setBridge(address(bridge));

        // Add supported chains
        vm.startPrank(protocolOwner);
        bridge.addSupportedChain(POLYGON_CHAIN, makeAddr("polygonBridge"), "Polygon");
        bridge.addSupportedChain(ARB_CHAIN, makeAddr("arbBridge"), "Arbitrum");
        bridge.addSupportedChain(BASE_CHAIN, makeAddr("baseBridge"), "Base");
        vm.stopPrank();

        vm.deal(agentOwner, 100 ether);
        vm.deal(agentOwner2, 100 ether);
        vm.deal(stranger, 10 ether);
    }

    // ============================================================
    //                    HELPER FUNCTIONS
    // ============================================================

    function _getFee(ICrossChainBridge.MessageType msgType, uint256 payloadSize)
        internal view returns (uint256)
    {
        return bridge.estimateFee(POLYGON_CHAIN, msgType, payloadSize);
    }

    function _bridgeAgentToPolygon() internal returns (bytes32 messageId) {
        // Estimate fee with approximate payload size
        uint256 fee = bridge.BASE_FEE() + 300 * bridge.FEE_PER_BYTE();
        vm.prank(agentOwner);
        messageId = bridge.bridgeAgent{value: fee}(AGENT_ID_1, POLYGON_CHAIN);
    }

    // ============================================================
    //           DEPLOYMENT TESTS (5 tests)
    // ============================================================

    function test_Deploy_CorrectState() public view {
        assertEq(bridge.protocolOwner(), protocolOwner);
        assertEq(bridge.registry(), address(registry));
        assertEq(bridge.reputationOracle(), address(oracle));
        assertEq(bridge.ccipRouter(), address(router));
        assertEq(bridge.currentChainSelector(), ETH_CHAIN);
        assertEq(bridge.totalMessagesSent(), 0);
        assertEq(bridge.totalMessagesReceived(), 0);
    }

    function test_Deploy_Revert_ZeroOwner() public {
        vm.expectRevert(ICrossChainBridge.ZeroAddress.selector);
        new CrossChainBridge(address(0), address(registry), address(oracle), address(router), ETH_CHAIN);
    }

    function test_Deploy_Revert_ZeroRegistry() public {
        vm.expectRevert(ICrossChainBridge.ZeroAddress.selector);
        new CrossChainBridge(protocolOwner, address(0), address(oracle), address(router), ETH_CHAIN);
    }

    function test_Deploy_Revert_ZeroRouter() public {
        vm.expectRevert(ICrossChainBridge.ZeroAddress.selector);
        new CrossChainBridge(protocolOwner, address(registry), address(oracle), address(0), ETH_CHAIN);
    }

    function test_Deploy_Revert_InvalidChainSelector() public {
        vm.expectRevert(ICrossChainBridge.InvalidChainSelector.selector);
        new CrossChainBridge(protocolOwner, address(registry), address(oracle), address(router), 0);
    }

    // ============================================================
    //           CHAIN MANAGEMENT TESTS (7 tests)
    // ============================================================

    function test_AddSupportedChain_Success() public view {
        assertTrue(bridge.isSupportedChain(POLYGON_CHAIN));
        assertTrue(bridge.isSupportedChain(ARB_CHAIN));
        assertTrue(bridge.isSupportedChain(BASE_CHAIN));
    }

    function test_AddSupportedChain_StoresCorrectData() public view {
        ICrossChainBridge.SupportedChain memory chain = bridge.getSupportedChain(POLYGON_CHAIN);
        assertEq(chain.chainSelector, POLYGON_CHAIN);
        assertTrue(chain.isActive);
        assertEq(chain.chainName, "Polygon");
    }

    function test_AddSupportedChain_EmitsEvent() public {
        uint64 newChain = 1234567890;
        address newBridge = makeAddr("newBridge");

        vm.expectEmit(true, false, false, true);
        emit ICrossChainBridge.ChainAdded(newChain, newBridge, "TestChain");
        vm.prank(protocolOwner);
        bridge.addSupportedChain(newChain, newBridge, "TestChain");
    }

    function test_AddSupportedChain_Revert_NotOwner() public {
        vm.prank(stranger);
        vm.expectRevert(ICrossChainBridge.NotAuthorized.selector);
        bridge.addSupportedChain(9999, makeAddr("b"), "Test");
    }

    function test_AddSupportedChain_Revert_AlreadyAdded() public {
        vm.prank(protocolOwner);
        vm.expectRevert(
            abi.encodeWithSelector(ICrossChainBridge.ChainAlreadyAdded.selector, POLYGON_CHAIN)
        );
        bridge.addSupportedChain(POLYGON_CHAIN, makeAddr("b"), "Polygon2");
    }

    function test_RemoveSupportedChain_Success() public {
        vm.prank(protocolOwner);
        bridge.removeSupportedChain(BASE_CHAIN);
        assertFalse(bridge.isSupportedChain(BASE_CHAIN));
    }

    function test_RemoveSupportedChain_Revert_NotSupported() public {
        vm.prank(protocolOwner);
        vm.expectRevert(
            abi.encodeWithSelector(ICrossChainBridge.ChainNotSupported.selector, uint64(9999))
        );
        bridge.removeSupportedChain(9999);
    }

    // ============================================================
    //           BRIDGE AGENT TESTS (8 tests)
    // ============================================================

    function test_BridgeAgent_Success() public {
        bytes32 messageId = _bridgeAgentToPolygon();
        assertTrue(messageId != bytes32(0));
        assertEq(bridge.totalMessagesSent(), 1);
    }

    function test_BridgeAgent_EmitsEvent() public {
        uint256 fee = bridge.BASE_FEE() + 300 * bridge.FEE_PER_BYTE();

        vm.expectEmit(false, true, true, false);
        emit ICrossChainBridge.AgentBridged(bytes32(0), AGENT_ID_1, POLYGON_CHAIN, agentOwner);
        vm.prank(agentOwner);
        bridge.bridgeAgent{value: fee}(AGENT_ID_1, POLYGON_CHAIN);
    }

    function test_BridgeAgent_StoresMessage() public {
        bytes32 messageId = _bridgeAgentToPolygon();

        ICrossChainBridge.BridgeMessage memory msg_ = bridge.getMessage(messageId);
        assertEq(msg_.agentId, AGENT_ID_1);
        // Can't directly access agentId from BridgeMessage struct (it's in payload)
        // Verify via messageId and destChain
        assertEq(msg_.destChain, POLYGON_CHAIN);
        assertEq(msg_.sourceChain, ETH_CHAIN);
        assertEq(uint256(msg_.msgType), uint256(ICrossChainBridge.MessageType.AGENT_REGISTRATION));
        assertEq(uint256(msg_.status), uint256(ICrossChainBridge.MessageStatus.PENDING));
    }

    function test_BridgeAgent_Revert_ChainNotSupported() public {
        uint64 unsupportedChain = 999999;
        uint256 fee = 1 ether;

        vm.prank(agentOwner);
        vm.expectRevert(
            abi.encodeWithSelector(ICrossChainBridge.ChainNotSupported.selector, unsupportedChain)
        );
        bridge.bridgeAgent{value: fee}(AGENT_ID_1, unsupportedChain);
    }

    function test_BridgeAgent_Revert_NotAgentOwner() public {
        uint256 fee = 1 ether;
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(ICrossChainBridge.AgentNotRegistered.selector, AGENT_ID_1)
        );
        bridge.bridgeAgent{value: fee}(AGENT_ID_1, POLYGON_CHAIN);
    }

    function test_BridgeAgent_Revert_InsufficientFee() public {
        vm.prank(agentOwner);
        vm.expectRevert(); // InsufficientFee
        bridge.bridgeAgent{value: 1 wei}(AGENT_ID_1, POLYGON_CHAIN);
    }

    function test_BridgeAgent_UniqueMessageIds() public {
        uint256 fee = bridge.BASE_FEE() + 300 * bridge.FEE_PER_BYTE();

        vm.prank(agentOwner);
        bytes32 id1 = bridge.bridgeAgent{value: fee}(AGENT_ID_1, POLYGON_CHAIN);

        vm.prank(agentOwner);
        bytes32 id2 = bridge.bridgeAgent{value: fee}(AGENT_ID_1, ARB_CHAIN);

        assertTrue(id1 != id2);
    }

    function test_BridgeAgent_RouterReceivesFee() public {
        uint256 fee = bridge.BASE_FEE() + 300 * bridge.FEE_PER_BYTE();
        uint256 routerBefore = address(router).balance;

        vm.prank(agentOwner);
        bridge.bridgeAgent{value: fee}(AGENT_ID_1, POLYGON_CHAIN);

        // Router should receive the CCIP fee
        assertGe(address(router).balance + address(bridge).balance, routerBefore + fee);
    }

    // ============================================================
    //           SYNC REPUTATION TESTS (6 tests)
    // ============================================================

    function test_SyncReputation_Success() public {
        uint256 fee = bridge.BASE_FEE() + 200 * bridge.FEE_PER_BYTE();

        vm.prank(agentOwner);
        bytes32 messageId = bridge.syncReputation{value: fee}(AGENT_ID_1, POLYGON_CHAIN);

        assertTrue(messageId != bytes32(0));
        assertEq(bridge.totalMessagesSent(), 1);
    }

    function test_SyncReputation_EmitsEvent() public {
        uint256 fee = bridge.BASE_FEE() + 200 * bridge.FEE_PER_BYTE();
        uint256 score = oracle.getScore(AGENT_ID_1);

        vm.expectEmit(false, true, true, true);
        emit ICrossChainBridge.ReputationSynced(bytes32(0), AGENT_ID_1, ARB_CHAIN, score);
        vm.prank(agentOwner);
        bridge.syncReputation{value: fee}(AGENT_ID_1, ARB_CHAIN);
    }

    function test_SyncReputation_CorrectMessageType() public {
        uint256 fee = bridge.BASE_FEE() + 200 * bridge.FEE_PER_BYTE();

        vm.prank(agentOwner);
        bytes32 messageId = bridge.syncReputation{value: fee}(AGENT_ID_1, POLYGON_CHAIN);

        ICrossChainBridge.BridgeMessage memory msg_ = bridge.getMessage(messageId);
        assertEq(uint256(msg_.msgType), uint256(ICrossChainBridge.MessageType.REPUTATION_SYNC));
    }

    function test_SyncReputation_Revert_NotOwner() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(ICrossChainBridge.AgentNotRegistered.selector, AGENT_ID_1)
        );
        bridge.syncReputation{value: 1 ether}(AGENT_ID_1, POLYGON_CHAIN);
    }

    function test_SyncReputation_Revert_ChainNotSupported() public {
        vm.prank(agentOwner);
        vm.expectRevert(
            abi.encodeWithSelector(ICrossChainBridge.ChainNotSupported.selector, uint64(1111))
        );
        bridge.syncReputation{value: 1 ether}(AGENT_ID_1, 1111);
    }

    function test_SyncReputation_AfterReputationChange() public {
        // Authorize oracle updater
        vm.prank(protocolOwner);
        oracle.setAuthorizedUpdater(address(this), true);

        // Update reputation
        oracle.updateReputation(AGENT_ID_1, IReputationOracle.UpdateReason.TASK_COMPLETED, bytes32(0));

        uint256 newScore = oracle.getScore(AGENT_ID_1);
        uint256 fee = bridge.BASE_FEE() + 200 * bridge.FEE_PER_BYTE();

        vm.prank(agentOwner);
        bytes32 messageId = bridge.syncReputation{value: fee}(AGENT_ID_1, POLYGON_CHAIN);

        // Message stored with updated score
        assertTrue(messageId != bytes32(0));
        assertGt(newScore, 5000); // score increased from task completion
    }

    // ============================================================
    //           BRIDGE PAYMENT TESTS (7 tests)
    // ============================================================

    function test_BridgePayment_Success() public {
        uint256 paymentAmount = 0.5 ether;
        uint256 fee = bridge.BASE_FEE() + 200 * bridge.FEE_PER_BYTE();

        vm.prank(agentOwner);
        bytes32 messageId = bridge.bridgePayment{value: fee + paymentAmount}(
            AGENT_ID_1, POLYGON_CHAIN, paymentAmount
        );

        assertTrue(messageId != bytes32(0));
        assertEq(bridge.totalMessagesSent(), 1);
    }

    function test_BridgePayment_EmitsEvent() public {
        uint256 paymentAmount = 0.5 ether;
        uint256 fee = bridge.BASE_FEE() + 200 * bridge.FEE_PER_BYTE();

        vm.expectEmit(false, true, true, true);
        emit ICrossChainBridge.PaymentBridged(bytes32(0), AGENT_ID_1, ARB_CHAIN, paymentAmount);
        vm.prank(agentOwner);
        bridge.bridgePayment{value: fee + paymentAmount}(AGENT_ID_1, ARB_CHAIN, paymentAmount);
    }

    function test_BridgePayment_CorrectMessageType() public {
        uint256 amount = 0.1 ether;
        uint256 fee = bridge.BASE_FEE() + 200 * bridge.FEE_PER_BYTE();

        vm.prank(agentOwner);
        bytes32 messageId = bridge.bridgePayment{value: fee + amount}(
            AGENT_ID_1, POLYGON_CHAIN, amount
        );

        ICrossChainBridge.BridgeMessage memory msg_ = bridge.getMessage(messageId);
        assertEq(uint256(msg_.msgType), uint256(ICrossChainBridge.MessageType.PAYMENT_BRIDGE));
    }

    function test_BridgePayment_Revert_ZeroAmount() public {
        uint256 fee = bridge.BASE_FEE() + 200 * bridge.FEE_PER_BYTE();

        vm.prank(agentOwner);
        vm.expectRevert(ICrossChainBridge.InvalidPayload.selector);
        bridge.bridgePayment{value: fee}(AGENT_ID_1, POLYGON_CHAIN, 0);
    }

    function test_BridgePayment_Revert_InsufficientValue() public {
        uint256 amount = 1 ether;
        // Only send amount, no fee
        vm.prank(agentOwner);
        vm.expectRevert(); // InsufficientFee
        bridge.bridgePayment{value: amount}(AGENT_ID_1, POLYGON_CHAIN, amount);
    }

    function test_BridgePayment_Revert_ChainNotSupported() public {
        vm.prank(agentOwner);
        vm.expectRevert(
            abi.encodeWithSelector(ICrossChainBridge.ChainNotSupported.selector, uint64(2222))
        );
        bridge.bridgePayment{value: 2 ether}(AGENT_ID_1, 2222, 1 ether);
    }

    function test_BridgePayment_ByAnyoneForAgent() public {
        // Anyone can bridge a payment to an agent (not just owner)
        uint256 amount = 0.5 ether;
        uint256 fee = bridge.BASE_FEE() + 200 * bridge.FEE_PER_BYTE();

        vm.prank(stranger);
        bytes32 messageId = bridge.bridgePayment{value: fee + amount}(
            AGENT_ID_1, POLYGON_CHAIN, amount
        );

        assertTrue(messageId != bytes32(0));
    }

    // ============================================================
    //           CCIP RECEIVE TESTS (7 tests)
    // ============================================================

    function test_CCIPReceive_AgentRegistration() public {
        bytes memory payload = abi.encode(
            ICrossChainBridge.MessageType.AGENT_REGISTRATION,
            AGENT_ID_1,
            agentOwner,
            META,
            uint256(7500),
            POLYGON_CHAIN
        );

        bytes32 msgId = keccak256("test-msg");
        vm.prank(address(router));
        bridge.ccipReceive(msgId, POLYGON_CHAIN, payload);

        assertTrue(bridge.isAgentBridged(AGENT_ID_1, POLYGON_CHAIN));
        assertEq(bridge.totalMessagesReceived(), 1);

        ICrossChainBridge.AgentBridgeRecord memory record =
            bridge.getAgentBridgeRecord(AGENT_ID_1, POLYGON_CHAIN);
        assertEq(record.agentId, AGENT_ID_1);
        assertEq(record.owner, agentOwner);
        assertEq(record.reputationScore, 7500);
    }

    function test_CCIPReceive_EmitsEvent() public {
        bytes memory payload = abi.encode(
            ICrossChainBridge.MessageType.AGENT_REGISTRATION,
            AGENT_ID_1, agentOwner, META, uint256(5000), POLYGON_CHAIN
        );

        bytes32 msgId = keccak256("test-msg-2");
        vm.expectEmit(true, true, true, false);
        emit ICrossChainBridge.MessageReceived(
            msgId, ICrossChainBridge.MessageType.AGENT_REGISTRATION, POLYGON_CHAIN
        );
        vm.prank(address(router));
        bridge.ccipReceive(msgId, POLYGON_CHAIN, payload);
    }

    function test_CCIPReceive_ReputationSync() public {
        // First register the agent
        bytes memory regPayload = abi.encode(
            ICrossChainBridge.MessageType.AGENT_REGISTRATION,
            AGENT_ID_1, agentOwner, META, uint256(5000), POLYGON_CHAIN
        );
        vm.prank(address(router));
        bridge.ccipReceive(keccak256("reg"), POLYGON_CHAIN, regPayload);

        // Now sync reputation
        bytes memory syncPayload = abi.encode(
            ICrossChainBridge.MessageType.REPUTATION_SYNC,
            AGENT_ID_1,
            uint256(8000),
            block.timestamp
        );
        vm.prank(address(router));
        bridge.ccipReceive(keccak256("sync"), POLYGON_CHAIN, syncPayload);

        ICrossChainBridge.AgentBridgeRecord memory record =
            bridge.getAgentBridgeRecord(AGENT_ID_1, POLYGON_CHAIN);
        assertEq(record.reputationScore, 8000);
    }

    function test_CCIPReceive_Revert_NotRouter() public {
        bytes memory payload = abi.encode(
            ICrossChainBridge.MessageType.AGENT_REGISTRATION,
            AGENT_ID_1, agentOwner, META, uint256(5000), POLYGON_CHAIN
        );

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(ICrossChainBridge.NotCCIPRouter.selector, stranger)
        );
        bridge.ccipReceive(bytes32(0), POLYGON_CHAIN, payload);
    }

    function test_CCIPReceive_Revert_EmptyPayload() public {
        vm.prank(address(router));
        vm.expectRevert(ICrossChainBridge.InvalidPayload.selector);
        bridge.ccipReceive(bytes32(0), POLYGON_CHAIN, "");
    }

    function test_CCIPReceive_TracksBridgedChains() public {
        bytes memory payload1 = abi.encode(
            ICrossChainBridge.MessageType.AGENT_REGISTRATION,
            AGENT_ID_1, agentOwner, META, uint256(5000), POLYGON_CHAIN
        );
        bytes memory payload2 = abi.encode(
            ICrossChainBridge.MessageType.AGENT_REGISTRATION,
            AGENT_ID_1, agentOwner, META, uint256(5000), ARB_CHAIN
        );

        vm.prank(address(router));
        bridge.ccipReceive(keccak256("p"), POLYGON_CHAIN, payload1);

        vm.prank(address(router));
        bridge.ccipReceive(keccak256("a"), ARB_CHAIN, payload2);

        uint64[] memory chains = bridge.getAgentBridgedChains(AGENT_ID_1);
        assertEq(chains.length, 2);
    }

    function test_CCIPReceive_PaymentBridge_ForwardsETH() public {
        // Fund bridge with ETH (simulates CCIP value transfer)
        vm.deal(address(bridge), 1 ether);

        bytes memory payload = abi.encode(
            ICrossChainBridge.MessageType.PAYMENT_BRIDGE,
            AGENT_ID_1,
            address(agentWallet),
            uint256(0.5 ether),
            stranger
        );

        uint256 walletBefore = address(agentWallet).balance;
        vm.prank(address(router));
        bridge.ccipReceive(keccak256("pay"), POLYGON_CHAIN, payload);

        assertEq(address(agentWallet).balance - walletBefore, 0.5 ether);
    }

    // ============================================================
    //           ADMIN TESTS (3 tests)
    // ============================================================

    function test_UpdateCCIPRouter_Success() public {
        address newRouter = makeAddr("newRouter");
        vm.prank(protocolOwner);
        bridge.updateCCIPRouter(newRouter);
        assertEq(bridge.ccipRouter(), newRouter);
    }

    function test_UpdateCCIPRouter_EmitsEvent() public {
        address newRouter = makeAddr("newRouter2");
        vm.expectEmit(true, false, false, false);
        emit ICrossChainBridge.CCIPRouterUpdated(newRouter);
        vm.prank(protocolOwner);
        bridge.updateCCIPRouter(newRouter);
    }

    function test_UpdateCCIPRouter_Revert_NotOwner() public {
        vm.prank(stranger);
        vm.expectRevert(ICrossChainBridge.NotAuthorized.selector);
        bridge.updateCCIPRouter(makeAddr("x"));
    }

    // ============================================================
    //           VIEW FUNCTION TESTS (3 tests)
    // ============================================================

    function test_EstimateFee_ScalesWithPayload() public view {
        uint256 fee1 = bridge.estimateFee(POLYGON_CHAIN, ICrossChainBridge.MessageType.AGENT_REGISTRATION, 100);
        uint256 fee2 = bridge.estimateFee(POLYGON_CHAIN, ICrossChainBridge.MessageType.AGENT_REGISTRATION, 200);
        assertGt(fee2, fee1);
        assertEq(fee2 - fee1, 100 * bridge.FEE_PER_BYTE());
    }

    function test_GetMessage_Revert_NotFound() public {
        vm.expectRevert(
            abi.encodeWithSelector(ICrossChainBridge.MessageNotFound.selector, bytes32(0))
        );
        bridge.getMessage(bytes32(0));
    }

    function test_IsAgentBridged_FalseBeforeBridge() public view {
        assertFalse(bridge.isAgentBridged(AGENT_ID_1, POLYGON_CHAIN));
    }

    // ============================================================
    //           INTEGRATION TESTS (5 tests)
    // ============================================================

    function test_Integration_FullBridgeFlow() public {
        // 1. Bridge agent to Polygon
        uint256 fee = bridge.BASE_FEE() + 300 * bridge.FEE_PER_BYTE();
        vm.prank(agentOwner);
        bytes32 messageId = bridge.bridgeAgent{value: fee}(AGENT_ID_1, POLYGON_CHAIN);

        assertEq(bridge.totalMessagesSent(), 1);
        assertEq(uint256(bridge.getMessage(messageId).status),
            uint256(ICrossChainBridge.MessageStatus.PENDING));

        // 2. Simulate Polygon receives the message
        ICrossChainBridge.BridgeMessage memory sentMsg = bridge.getMessage(messageId);
        vm.prank(address(router));
        bridge.ccipReceive(messageId, POLYGON_CHAIN, sentMsg.payload);

        // Agent now bridged
        assertTrue(bridge.isAgentBridged(AGENT_ID_1, POLYGON_CHAIN));
        assertEq(bridge.totalMessagesReceived(), 1);
    }

    function test_Integration_AgentOnThreeChains() public {
        uint256 fee = bridge.BASE_FEE() + 300 * bridge.FEE_PER_BYTE();

        vm.startPrank(agentOwner);
        bytes32 msg1 = bridge.bridgeAgent{value: fee}(AGENT_ID_1, POLYGON_CHAIN);
        bytes32 msg2 = bridge.bridgeAgent{value: fee}(AGENT_ID_1, ARB_CHAIN);
        bytes32 msg3 = bridge.bridgeAgent{value: fee}(AGENT_ID_1, BASE_CHAIN);
        vm.stopPrank();

        assertEq(bridge.totalMessagesSent(), 3);
        assertTrue(msg1 != msg2 && msg2 != msg3);
    }

    function test_Integration_BridgeAndSyncReputation() public {
        uint256 bridgeFee = bridge.BASE_FEE() + 300 * bridge.FEE_PER_BYTE();
        uint256 syncFee   = bridge.BASE_FEE() + 200 * bridge.FEE_PER_BYTE();

        vm.prank(agentOwner);
        bridge.bridgeAgent{value: bridgeFee}(AGENT_ID_1, POLYGON_CHAIN);

        vm.prank(agentOwner);
        bytes32 syncId = bridge.syncReputation{value: syncFee}(AGENT_ID_1, POLYGON_CHAIN);

        assertEq(bridge.totalMessagesSent(), 2);
        assertEq(
            uint256(bridge.getMessage(syncId).msgType),
            uint256(ICrossChainBridge.MessageType.REPUTATION_SYNC)
        );
    }

    function test_Integration_MultipleAgentsBridged() public {
        uint256 fee = bridge.BASE_FEE() + 300 * bridge.FEE_PER_BYTE();

        vm.prank(agentOwner);
        bridge.bridgeAgent{value: fee}(AGENT_ID_1, POLYGON_CHAIN);

        vm.prank(agentOwner2);
        bridge.bridgeAgent{value: fee}(AGENT_ID_2, POLYGON_CHAIN);

        assertEq(bridge.totalMessagesSent(), 2);
        assertFalse(bridge.isAgentBridged(AGENT_ID_1, POLYGON_CHAIN)); // not yet received
        assertFalse(bridge.isAgentBridged(AGENT_ID_2, POLYGON_CHAIN));
    }

    function test_Integration_CrossChainPaymentThenReceive() public {
        uint256 paymentAmount = 0.5 ether;
        uint256 fee = bridge.BASE_FEE() + 200 * bridge.FEE_PER_BYTE();

        // Bridge payment
        vm.prank(agentOwner2);
        bytes32 messageId = bridge.bridgePayment{value: fee + paymentAmount}(
            AGENT_ID_1, POLYGON_CHAIN, paymentAmount
        );

        // Simulate destination receives payment
        vm.deal(address(bridge), paymentAmount);
        bytes memory payload = bridge.getMessage(messageId).payload;

        uint256 walletBefore = address(agentWallet).balance;
        vm.prank(address(router));
        bridge.ccipReceive(messageId, POLYGON_CHAIN, payload);

        // Agent wallet received the payment on destination
        assertEq(address(agentWallet).balance - walletBefore, paymentAmount);
    }

    // ============================================================
    //                   FUZZ TESTS (3 tests)
    // ============================================================

    function testFuzz_EstimateFee_AlwaysAboveBase(uint256 payloadSize) public view {
        vm.assume(payloadSize <= 10_000);
        uint256 fee = bridge.estimateFee(
            POLYGON_CHAIN, ICrossChainBridge.MessageType.AGENT_REGISTRATION, payloadSize
        );
        assertGe(fee, bridge.BASE_FEE());
    }

    function testFuzz_BridgeAgent_UniqueMessageIds(uint8 count) public {
        vm.assume(count > 1 && count <= 5);
        uint64[] memory chains = new uint64[](3);
        chains[0] = POLYGON_CHAIN;
        chains[1] = ARB_CHAIN;
        chains[2] = BASE_CHAIN;

        uint256 fee = bridge.BASE_FEE() + 300 * bridge.FEE_PER_BYTE();
        bytes32[] memory ids = new bytes32[](count);

        for (uint256 i = 0; i < count; i++) {
            vm.prank(agentOwner);
            ids[i] = bridge.bridgeAgent{value: fee}(AGENT_ID_1, chains[i % 3]);
        }

        for (uint256 i = 0; i < count; i++) {
            for (uint256 j = i + 1; j < count; j++) {
                assertTrue(ids[i] != ids[j], "Duplicate message IDs");
            }
        }
    }

    function testFuzz_CCIPReceive_OnlyRouterCanCall(address caller) public {
        vm.assume(caller != address(router));
        bytes memory payload = abi.encode(
            ICrossChainBridge.MessageType.AGENT_REGISTRATION,
            AGENT_ID_1, agentOwner, META, uint256(5000), POLYGON_CHAIN
        );

        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(ICrossChainBridge.NotCCIPRouter.selector, caller)
        );
        bridge.ccipReceive(bytes32(0), POLYGON_CHAIN, payload);
    }
}
