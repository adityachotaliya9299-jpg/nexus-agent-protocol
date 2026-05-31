// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";

contract AgentRegistryTest is Test {
    AgentRegistry public registry;

    address public protocolOwner = makeAddr("protocolOwner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public marketplace = makeAddr("marketplace");

    string constant METADATA_URI_1 = "ipfs://QmAliceAgentMetadataCID123456789";
    string constant METADATA_URI_2 = "ipfs://QmBobAgentMetadataCID987654321";
    string constant UPDATED_URI = "ipfs://QmUpdatedMetadataCID000111222";

    function setUp() public {
        registry = new AgentRegistry(protocolOwner);
    }

    // ============================================================
    //                    REGISTRATION TESTS
    // ============================================================

    function test_RegisterAgent_Success() public {
        vm.prank(alice);
        uint256 agentId = registry.registerAgent(METADATA_URI_1, IAgentRegistry.AgentCategory.CODE);

        assertEq(agentId, 1, "First agent should have ID 1");

        IAgentRegistry.AgentProfile memory profile = registry.getAgent(agentId);
        assertEq(profile.agentId, 1);
        assertEq(profile.owner, alice);
        assertEq(profile.agentWallet, address(0));
        assertEq(profile.metadataURI, METADATA_URI_1);
        assertEq(uint256(profile.category), uint256(IAgentRegistry.AgentCategory.CODE));
        assertEq(uint256(profile.status), uint256(IAgentRegistry.AgentStatus.ACTIVE));
        assertEq(profile.reputationScore, 5000);
        assertEq(profile.totalTasksCompleted, 0);
        assertEq(profile.totalEarned, 0);
    }

    function test_RegisterAgent_EmitsEvent() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit IAgentRegistry.AgentRegistered(
            1, alice, address(0), METADATA_URI_1, IAgentRegistry.AgentCategory.CODE
        );
        registry.registerAgent(METADATA_URI_1, IAgentRegistry.AgentCategory.CODE);
    }

    function test_RegisterMultipleAgents_UniqueIds() public {
        vm.prank(alice);
        uint256 id1 = registry.registerAgent(METADATA_URI_1, IAgentRegistry.AgentCategory.CODE);

        vm.prank(bob);
        uint256 id2 = registry.registerAgent(METADATA_URI_2, IAgentRegistry.AgentCategory.TRADING);

        assertEq(id1, 1);
        assertEq(id2, 2);
        assertEq(registry.totalAgents(), 2);
    }

    function test_RegisterAgent_Revert_AlreadyRegistered() public {
        vm.prank(alice);
        registry.registerAgent(METADATA_URI_1, IAgentRegistry.AgentCategory.CODE);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAgentRegistry.AgentAlreadyRegistered.selector, alice));
        registry.registerAgent(METADATA_URI_2, IAgentRegistry.AgentCategory.GENERAL);
    }

    function test_RegisterAgent_Revert_EmptyMetadata() public {
        vm.prank(alice);
        vm.expectRevert(IAgentRegistry.InvalidMetadataURI.selector);
        registry.registerAgent("", IAgentRegistry.AgentCategory.CODE);
    }

    // ============================================================
    //                     UPDATE TESTS
    // ============================================================

    function test_UpdateMetadata_Success() public {
        vm.prank(alice);
        uint256 agentId = registry.registerAgent(METADATA_URI_1, IAgentRegistry.AgentCategory.CODE);

        vm.prank(alice);
        registry.updateMetadata(agentId, UPDATED_URI);

        IAgentRegistry.AgentProfile memory profile = registry.getAgent(agentId);
        assertEq(profile.metadataURI, UPDATED_URI);
    }

    function test_UpdateMetadata_Revert_NotOwner() public {
        vm.prank(alice);
        uint256 agentId = registry.registerAgent(METADATA_URI_1, IAgentRegistry.AgentCategory.CODE);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IAgentRegistry.NotAgentOwner.selector, bob, agentId));
        registry.updateMetadata(agentId, UPDATED_URI);
    }

    function test_SetAgentStatus() public {
        vm.prank(alice);
        uint256 agentId = registry.registerAgent(METADATA_URI_1, IAgentRegistry.AgentCategory.CODE);

        vm.prank(alice);
        registry.setAgentStatus(agentId, IAgentRegistry.AgentStatus.BUSY);

        IAgentRegistry.AgentProfile memory profile = registry.getAgent(agentId);
        assertEq(uint256(profile.status), uint256(IAgentRegistry.AgentStatus.BUSY));
    }

    function test_SetAgentWallet_Success() public {
        address mockWallet = makeAddr("mockSmartWallet");

        vm.prank(alice);
        uint256 agentId = registry.registerAgent(METADATA_URI_1, IAgentRegistry.AgentCategory.CODE);

        vm.prank(alice);
        registry.setAgentWallet(agentId, mockWallet);

        IAgentRegistry.AgentProfile memory profile = registry.getAgent(agentId);
        assertEq(profile.agentWallet, mockWallet);
    }

    function test_SetAgentWallet_Revert_ZeroAddress() public {
        vm.prank(alice);
        uint256 agentId = registry.registerAgent(METADATA_URI_1, IAgentRegistry.AgentCategory.CODE);

        vm.prank(alice);
        vm.expectRevert(IAgentRegistry.ZeroAddress.selector);
        registry.setAgentWallet(agentId, address(0));
    }

    // ============================================================
    //                    REPUTATION TESTS
    // ============================================================

    function test_UpdateReputation_AuthorizedCaller() public {
        vm.prank(alice);
        uint256 agentId = registry.registerAgent(METADATA_URI_1, IAgentRegistry.AgentCategory.CODE);

        vm.prank(protocolOwner);
        registry.setReputationUpdater(marketplace, true);

        vm.prank(marketplace);
        registry.updateReputation(agentId, 7500, 1, 1 ether);

        IAgentRegistry.AgentProfile memory profile = registry.getAgent(agentId);
        assertEq(profile.reputationScore, 7500);
        assertEq(profile.totalTasksCompleted, 1);
        assertEq(profile.totalEarned, 1 ether);
    }

    function test_UpdateReputation_Revert_Unauthorized() public {
        vm.prank(alice);
        uint256 agentId = registry.registerAgent(METADATA_URI_1, IAgentRegistry.AgentCategory.CODE);

        vm.prank(bob);
        vm.expectRevert("Not authorized to update reputation");
        registry.updateReputation(agentId, 7500, 1, 1 ether);
    }

    function test_UpdateReputation_Revert_ScoreTooHigh() public {
        vm.prank(alice);
        uint256 agentId = registry.registerAgent(METADATA_URI_1, IAgentRegistry.AgentCategory.CODE);

        vm.prank(protocolOwner);
        registry.setReputationUpdater(marketplace, true);

        vm.prank(marketplace);
        vm.expectRevert("Score exceeds max (10000 basis points)");
        registry.updateReputation(agentId, 10001, 1, 0);
    }

    // ============================================================
    //                      VIEW TESTS
    // ============================================================

    function test_GetAgentByOwner() public {
        vm.prank(alice);
        registry.registerAgent(METADATA_URI_1, IAgentRegistry.AgentCategory.RESEARCH);

        IAgentRegistry.AgentProfile memory profile = registry.getAgentByOwner(alice);
        assertEq(profile.owner, alice);
        assertEq(profile.metadataURI, METADATA_URI_1);
    }

    function test_IsRegistered() public {
        assertEq(registry.isRegistered(alice), false);

        vm.prank(alice);
        registry.registerAgent(METADATA_URI_1, IAgentRegistry.AgentCategory.CODE);

        assertEq(registry.isRegistered(alice), true);
        assertEq(registry.isRegistered(bob), false);
    }

    function test_TotalAgents() public {
        assertEq(registry.totalAgents(), 0);

        vm.prank(alice);
        registry.registerAgent(METADATA_URI_1, IAgentRegistry.AgentCategory.CODE);
        assertEq(registry.totalAgents(), 1);

        vm.prank(bob);
        registry.registerAgent(METADATA_URI_2, IAgentRegistry.AgentCategory.TRADING);
        assertEq(registry.totalAgents(), 2);
    }

    function test_GetAgent_Revert_NotFound() public {
        vm.expectRevert(abi.encodeWithSelector(IAgentRegistry.AgentNotFound.selector, 999));
        registry.getAgent(999);
    }

    // ============================================================
    //                      FUZZ TESTS
    // ============================================================

    function testFuzz_RegisterAgent_ValidMetadata(string calldata metadata) public {
        vm.assume(bytes(metadata).length > 0);
        vm.assume(bytes(metadata).length < 500);

        vm.prank(alice);
        uint256 agentId = registry.registerAgent(metadata, IAgentRegistry.AgentCategory.GENERAL);
        assertGt(agentId, 0);

        IAgentRegistry.AgentProfile memory profile = registry.getAgent(agentId);
        assertEq(profile.metadataURI, metadata);
    }

    function testFuzz_UpdateReputation_ValidScore(uint256 score) public {
        vm.assume(score <= 10000);

        vm.prank(alice);
        uint256 agentId = registry.registerAgent(METADATA_URI_1, IAgentRegistry.AgentCategory.CODE);

        vm.prank(protocolOwner);
        registry.setReputationUpdater(marketplace, true);

        vm.prank(marketplace);
        registry.updateReputation(agentId, score, 0, 0);

        assertEq(registry.getAgent(agentId).reputationScore, score);
    }
}
