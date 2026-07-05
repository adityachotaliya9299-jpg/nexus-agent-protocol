// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {L2Bridge} from "../src/bridge/L2Bridge.sol";
import {IL2Bridge} from "../src/bridge/IL2Bridge.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";

// ── Stubs ──────────────────────────────────────────────────────

contract MockRegistry {
    mapping(uint256 => address) public owners;
    mapping(uint256 => bool)    public exists;

    function addAgent(uint256 id, address owner) external {
        owners[id] = owner; exists[id] = true;
    }

    function getAgent(uint256 id) external view returns (IAgentRegistry.AgentProfile memory p) {
        require(exists[id], "not found");
        p.agentId = id; p.owner = owners[id];
        p.totalTasksCompleted = 5;
        p.totalEarned = 0.5 ether;
        return p;
    }
}

contract MockOracle {
    mapping(uint256 => uint256) public scores;
    function setScore(uint256 id, uint256 s) external { scores[id] = s; }
    function getScore(uint256 id) external view returns (uint256) {
        return scores[id] == 0 ? 5000 : scores[id];
    }
}

/// @notice Simulates the Optimism CrossDomainMessenger
contract MockMessenger {
    address public xDomainMessageSender;
    L2Bridge public target;

    function setTarget(address t) external { target = L2Bridge(t); }
    function setSender(address s) external { xDomainMessageSender = s; }

    function relayMessage(IL2Bridge.ReputationSnapshot calldata snapshot) external {
        target.receiveReputation(snapshot);
    }
}

// ── Tests ──────────────────────────────────────────────────────

contract L2BridgeTest is Test {
    L2Bridge      internal l1Bridge;
    L2Bridge      internal l2Bridge;
    MockRegistry  internal registry;
    MockOracle    internal oracle;
    MockMessenger internal messenger;

    address constant OWNER    = address(0xA11CE);
    address constant AGENT1   = address(0xA6E41);
    address constant STRANGER = address(0x577);

    uint256 constant AGENT_ID = 1;

    function setUp() public {
        registry  = new MockRegistry();
        oracle    = new MockOracle();
        messenger = new MockMessenger();

        registry.addAgent(AGENT_ID, AGENT1);
        oracle.setScore(AGENT_ID, 7500);

        // L1 bridge (isL2 = false)
        vm.prank(OWNER);
        l1Bridge = new L2Bridge(OWNER, address(registry), address(oracle), false);

        // L2 bridge (isL2 = true)
        vm.prank(OWNER);
        l2Bridge = new L2Bridge(OWNER, address(registry), address(oracle), true);

        // Wire peer bridges
        vm.prank(OWNER);
        l1Bridge.setPeerBridge(address(l2Bridge));
        vm.prank(OWNER);
        l2Bridge.setPeerBridge(address(l1Bridge));

        messenger.setTarget(address(l2Bridge));
    }

    // ── Deployment ───────────────────────────────────────────────

    function test_L1Bridge_IsNotL2() public view {
        assertFalse(l1Bridge.isL2());
    }

    function test_L2Bridge_IsL2() public view {
        assertTrue(l2Bridge.isL2());
    }

    function test_PeerBridge_Set() public view {
        assertEq(l1Bridge.peerBridge(), address(l2Bridge));
        assertEq(l2Bridge.peerBridge(), address(l1Bridge));
    }

    // ── BridgeReputation (L1 side) ────────────────────────────────

    function test_BridgeReputation_NotOwner_Reverts() public {
        vm.prank(STRANGER);
        vm.expectRevert(IL2Bridge.NotAuthorized.selector);
        l1Bridge.bridgeReputation(AGENT_ID);
    }

    function test_BridgeReputation_OnL2_Reverts() public {
        vm.prank(AGENT1);
        vm.expectRevert(IL2Bridge.NotAuthorized.selector);
        l2Bridge.bridgeReputation(AGENT_ID);
    }

    // ── ReceiveReputation (L2 side) ───────────────────────────────

    function _makeSnapshot() internal view returns (IL2Bridge.ReputationSnapshot memory) {
        uint256[6] memory cats;
        return IL2Bridge.ReputationSnapshot({
            agentId:             AGENT_ID,
            owner:               AGENT1,
            globalScore:         7500,
            categoryScores:      cats,
            totalTasksCompleted: 5,
            totalEarned:         0.5 ether,
            snapshotBlock:       block.number,
            snapshotTimestamp:   block.timestamp
        });
    }

    function test_ReceiveReputation_NotMessenger_Reverts() public {
        vm.prank(STRANGER);
        vm.expectRevert(IL2Bridge.NotAuthorized.selector);
        l2Bridge.receiveReputation(_makeSnapshot());
    }

    function test_SnapshotStored_AfterReceive() public {
        // Simulate the L2 messenger calling receiveReputation
        // by pranking as the L2 messenger with peer set as sender
        address l2MessengerAddr = l2Bridge.L2_MESSENGER();

        vm.mockCall(
            l2MessengerAddr,
            abi.encodeWithSignature("xDomainMessageSender()"),
            abi.encode(address(l1Bridge))
        );

        vm.prank(l2MessengerAddr);
        l2Bridge.receiveReputation(_makeSnapshot());

        IL2Bridge.ReputationSnapshot memory snap = l2Bridge.getBridgedSnapshot(AGENT_ID);
        assertEq(snap.agentId, AGENT_ID);
        assertEq(snap.globalScore, 7500);
        assertEq(snap.totalTasksCompleted, 5);
        assertTrue(l2Bridge.hasBridgedReputation(AGENT_ID));
    }

    function test_HasBridgedReputation_FalseBeforeBridge() public view {
        assertFalse(l2Bridge.hasBridgedReputation(AGENT_ID));
    }

    function test_HasBridgedReputation_ExpiredAfterValidity() public {
        address l2MessengerAddr = l2Bridge.L2_MESSENGER();
        vm.mockCall(
            l2MessengerAddr,
            abi.encodeWithSignature("xDomainMessageSender()"),
            abi.encode(address(l1Bridge))
        );

        vm.prank(l2MessengerAddr);
        l2Bridge.receiveReputation(_makeSnapshot());

        assertTrue(l2Bridge.hasBridgedReputation(AGENT_ID));

        // Advance past validity window
        vm.warp(block.timestamp + 7 days + 1);
        assertFalse(l2Bridge.hasBridgedReputation(AGENT_ID));
    }

    function test_DuplicateMessage_Reverts() public {
        address l2MessengerAddr = l2Bridge.L2_MESSENGER();
        vm.mockCall(
            l2MessengerAddr,
            abi.encodeWithSignature("xDomainMessageSender()"),
            abi.encode(address(l1Bridge))
        );

        IL2Bridge.ReputationSnapshot memory snap = _makeSnapshot();

        vm.prank(l2MessengerAddr);
        l2Bridge.receiveReputation(snap);

        vm.prank(l2MessengerAddr);
        vm.expectRevert(); // MessageAlreadyProcessed
        l2Bridge.receiveReputation(snap);
    }

    // ── Admin ────────────────────────────────────────────────────

    function test_SetPeerBridge_OnlyOwner() public {
        vm.prank(STRANGER);
        vm.expectRevert(IL2Bridge.NotAuthorized.selector);
        l1Bridge.setPeerBridge(address(0x1234));
    }

    function test_SetPeerBridge_ZeroAddress_Reverts() public {
        vm.prank(OWNER);
        vm.expectRevert(IL2Bridge.ZeroAddress.selector);
        l1Bridge.setPeerBridge(address(0));
    }

    // ── Fuzz ─────────────────────────────────────────────────────

    function testFuzz_Snapshot_ScoreAlwaysStored(uint256 score) public {
        score = bound(score, 0, 10000);

        address l2MessengerAddr = l2Bridge.L2_MESSENGER();
        vm.mockCall(
            l2MessengerAddr,
            abi.encodeWithSignature("xDomainMessageSender()"),
            abi.encode(address(l1Bridge))
        );

        uint256[6] memory cats;
        IL2Bridge.ReputationSnapshot memory snap = IL2Bridge.ReputationSnapshot({
            agentId:             AGENT_ID,
            owner:               AGENT1,
            globalScore:         score,
            categoryScores:      cats,
            totalTasksCompleted: 0,
            totalEarned:         0,
            snapshotBlock:       block.number,
            snapshotTimestamp:   block.timestamp
        });

        vm.prank(l2MessengerAddr);
        l2Bridge.receiveReputation(snap);

        assertEq(l2Bridge.getBridgedSnapshot(AGENT_ID).globalScore, score);
    }
}
