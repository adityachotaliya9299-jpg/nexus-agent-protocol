// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AgentMemory} from "../src/memory/AgentMemory.sol";
import {IAgentMemory} from "../src/interfaces/IAgentMemory.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";

contract AgentMemoryTest is Test {
    // ============================================================
    //                         SETUP
    // ============================================================

    AgentMemory public memory_;
    AgentRegistry public registry;

    address public protocolOwner = makeAddr("protocolOwner");
    address public marketplace   = makeAddr("marketplace");   // authorized writer
    address public alice         = makeAddr("alice");         // agent 1 owner
    address public bob           = makeAddr("bob");           // agent 2 owner
    address public charlie       = makeAddr("charlie");       // unauthorized
    address public dave          = makeAddr("dave");          // READ grantee
    address public eve           = makeAddr("eve");           // WRITE grantee

    uint256 constant ALICE_ID = 1;
    uint256 constant BOB_ID   = 2;

    // Sample IPFS CIDs
    string constant CID_1 = "ipfs://QmAliceContext001";
    string constant CID_2 = "ipfs://QmAliceContext002";
    string constant CID_3 = "ipfs://QmAliceSkills001";

    bytes32 constant HASH_1 = keccak256("alice-context-v1");
    bytes32 constant HASH_2 = keccak256("alice-context-v2");
    bytes32 constant HASH_3 = keccak256("alice-skills-v1");

    string constant META = "ipfs://QmAgentMeta";

    function setUp() public {
        // Deploy registry and register agents
        registry = new AgentRegistry(protocolOwner);

        vm.prank(alice);
        registry.registerAgent(META, IAgentRegistry.AgentCategory.CODE);

        vm.prank(bob);
        registry.registerAgent(META, IAgentRegistry.AgentCategory.TRADING);

        // Deploy AgentMemory
        memory_ = new AgentMemory(protocolOwner, address(registry));

        // Authorize marketplace as writer
        vm.prank(protocolOwner);
        memory_.setAuthorizedWriter(marketplace, true);
    }

    // ============================================================
    //           DEPLOYMENT TESTS (3 tests)
    // ============================================================

    function test_Deploy_CorrectState() public view {
        assertEq(memory_.protocolOwner(), protocolOwner);
        assertEq(memory_.registry(), address(registry));
        assertTrue(memory_.isAuthorizedWriter(marketplace));
    }

    function test_Deploy_Revert_ZeroOwner() public {
        vm.expectRevert(IAgentMemory.ZeroAddress.selector);
        new AgentMemory(address(0), address(registry));
    }

    function test_Deploy_Revert_ZeroRegistry() public {
        vm.expectRevert(IAgentMemory.ZeroAddress.selector);
        new AgentMemory(protocolOwner, address(0));
    }

    // ============================================================
    //           INITIALIZATION TESTS (5 tests)
    // ============================================================

    function test_InitializeAgent_ByProtocolOwner() public {
        vm.prank(protocolOwner);
        memory_.initializeAgent(ALICE_ID, alice);

        assertTrue(memory_.isInitialized(ALICE_ID));
        assertEq(memory_.getMemoryOwner(ALICE_ID), alice);
    }

    function test_InitializeAgent_ByAuthorizedWriter() public {
        vm.prank(marketplace);
        memory_.initializeAgent(ALICE_ID, alice);

        assertTrue(memory_.isInitialized(ALICE_ID));
    }

    function test_InitializeAgent_EmitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit IAgentMemory.MemoryAgentInitialized(ALICE_ID, alice);
        vm.prank(protocolOwner);
        memory_.initializeAgent(ALICE_ID, alice);
    }

    function test_InitializeAgent_Revert_AlreadyInitialized() public {
        _initAlice();
        vm.prank(protocolOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IAgentMemory.AlreadyInitialized.selector, ALICE_ID)
        );
        memory_.initializeAgent(ALICE_ID, alice);
    }

    function test_InitializeAgent_Revert_Unauthorized() public {
        vm.prank(charlie);
        vm.expectRevert("Not authorized to initialize");
        memory_.initializeAgent(ALICE_ID, alice);
    }

    // ============================================================
    //           WRITE MEMORY TESTS (8 tests)
    // ============================================================

    function test_WriteMemory_ByOwner_Success() public {
        _initAlice();

        vm.prank(alice);
        uint256 version = memory_.writeMemory(
            ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_1, HASH_1
        );

        assertEq(version, 1);
        assertEq(memory_.getCurrentVersion(ALICE_ID, IAgentMemory.MemoryType.CONTEXT), 1);
    }

    function test_WriteMemory_ByAuthorizedWriter() public {
        _initAlice();

        vm.prank(marketplace);
        uint256 version = memory_.writeMemory(
            ALICE_ID, IAgentMemory.MemoryType.TASK_HISTORY, CID_1, HASH_1
        );

        assertEq(version, 1);
    }

    function test_WriteMemory_VersionIncrementsMonotonically() public {
        _initAlice();

        vm.startPrank(alice);
        uint256 v1 = memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_1, HASH_1);
        uint256 v2 = memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_2, HASH_2);
        uint256 v3 = memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_2, HASH_2);
        vm.stopPrank();

        assertEq(v1, 1);
        assertEq(v2, 2);
        assertEq(v3, 3);
    }

    function test_WriteMemory_DifferentTypes_IndependentVersions() public {
        _initAlice();

        vm.startPrank(alice);
        uint256 ctxV1 = memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_1, HASH_1);
        uint256 ctxV2 = memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_2, HASH_2);
        uint256 skillsV1 = memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.SKILLS, CID_3, HASH_3);
        vm.stopPrank();

        assertEq(ctxV1, 1);
        assertEq(ctxV2, 2);
        assertEq(skillsV1, 1); // Skills starts fresh at version 1
    }

    function test_WriteMemory_EmitsEvent() public {
        _initAlice();

        vm.expectEmit(true, true, true, true);
        emit IAgentMemory.MemoryWritten(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, 1, CID_1, alice);
        vm.prank(alice);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_1, HASH_1);
    }

    function test_WriteMemory_Revert_NotInitialized() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAgentMemory.AgentNotInitialized.selector, ALICE_ID)
        );
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_1, HASH_1);
    }

    function test_WriteMemory_Revert_InvalidCID() public {
        _initAlice();

        vm.prank(alice);
        vm.expectRevert(IAgentMemory.InvalidCID.selector);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, "", HASH_1);
    }

    function test_WriteMemory_Revert_InvalidHash() public {
        _initAlice();

        vm.prank(alice);
        vm.expectRevert(IAgentMemory.InvalidContentHash.selector);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_1, bytes32(0));
    }

    function test_WriteMemory_Revert_AccessDenied() public {
        _initAlice();

        vm.prank(charlie); // no access
        vm.expectRevert(
            abi.encodeWithSelector(IAgentMemory.AccessDenied.selector, ALICE_ID, charlie)
        );
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_1, HASH_1);
    }

    // ============================================================
    //           READ MEMORY TESTS (5 tests)
    // ============================================================

    function test_GetLatestMemory_ReturnsNewest() public {
        _initAlice();

        vm.startPrank(alice);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_1, HASH_1);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_2, HASH_2);
        vm.stopPrank();

        IAgentMemory.MemorySnapshot memory snap = memory_.getLatestMemory(
            ALICE_ID, IAgentMemory.MemoryType.CONTEXT
        );

        assertEq(snap.version, 2);
        assertEq(snap.cid, CID_2);
        assertEq(snap.contentHash, HASH_2);
        assertEq(snap.writtenBy, alice);
    }

    function test_GetMemoryVersion_SpecificVersion() public {
        _initAlice();

        vm.startPrank(alice);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_1, HASH_1);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_2, HASH_2);
        vm.stopPrank();

        IAgentMemory.MemorySnapshot memory snap = memory_.getMemoryVersion(
            ALICE_ID, IAgentMemory.MemoryType.CONTEXT, 1
        );

        assertEq(snap.version, 1);
        assertEq(snap.cid, CID_1);
        assertEq(snap.contentHash, HASH_1);
    }

    function test_GetMemoryHistory_AllVersions() public {
        _initAlice();

        vm.startPrank(alice);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.SKILLS, CID_1, HASH_1);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.SKILLS, CID_2, HASH_2);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.SKILLS, CID_3, HASH_3);
        vm.stopPrank();

        IAgentMemory.MemorySnapshot[] memory history = memory_.getMemoryHistory(
            ALICE_ID, IAgentMemory.MemoryType.SKILLS
        );

        assertEq(history.length, 3);
        assertEq(history[0].version, 1);
        assertEq(history[1].version, 2);
        assertEq(history[2].version, 3);
    }

    function test_GetLatestMemory_Revert_NoSnapshots() public {
        _initAlice();

        vm.expectRevert(
            abi.encodeWithSelector(IAgentMemory.VersionNotFound.selector, ALICE_ID, IAgentMemory.MemoryType.CONTEXT, 0)
        );
        memory_.getLatestMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT);
    }

    function test_GetMemoryVersion_Revert_NotFound() public {
        _initAlice();

        vm.prank(alice);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_1, HASH_1);

        vm.expectRevert(
            abi.encodeWithSelector(IAgentMemory.VersionNotFound.selector, ALICE_ID, IAgentMemory.MemoryType.CONTEXT, 99)
        );
        memory_.getMemoryVersion(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, 99);
    }

    // ============================================================
    //           ARCHIVE MEMORY TESTS (3 tests)
    // ============================================================

    function test_ArchiveMemory_Success() public {
        _initAlice();

        vm.prank(alice);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_1, HASH_1);

        vm.prank(alice);
        memory_.archiveMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, 1);

        IAgentMemory.MemorySnapshot memory snap = memory_.getMemoryVersion(
            ALICE_ID, IAgentMemory.MemoryType.CONTEXT, 1
        );
        assertTrue(snap.isArchived);
    }

    function test_ArchiveMemory_EmitsEvent() public {
        _initAlice();
        vm.prank(alice);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_1, HASH_1);

        vm.expectEmit(true, true, false, true);
        emit IAgentMemory.MemoryArchived(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, 1);
        vm.prank(alice);
        memory_.archiveMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, 1);
    }

    function test_ArchiveMemory_Revert_NotFound() public {
        _initAlice();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAgentMemory.VersionNotFound.selector, ALICE_ID, IAgentMemory.MemoryType.CONTEXT, 99
            )
        );
        memory_.archiveMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, 99);
    }

    // ============================================================
    //           ACCESS CONTROL TESTS (8 tests)
    // ============================================================

    function test_GrantAccess_Read_AllowsRead() public {
        _initAlice();

        vm.prank(alice);
        memory_.grantAccess(ALICE_ID, dave, IAgentMemory.AccessLevel.READ, 0);

        assertEq(
            uint256(memory_.getAccessLevel(ALICE_ID, dave)),
            uint256(IAgentMemory.AccessLevel.READ)
        );
        assertTrue(memory_.canRead(ALICE_ID, dave));
        assertFalse(memory_.canWrite(ALICE_ID, dave));
    }

    function test_GrantAccess_Write_AllowsWrite() public {
        _initAlice();
        vm.prank(alice);
        memory_.grantAccess(ALICE_ID, eve, IAgentMemory.AccessLevel.WRITE, 0);

        assertTrue(memory_.canWrite(ALICE_ID, eve));
        assertTrue(memory_.canRead(ALICE_ID, eve));
    }

    function test_GrantAccess_Admin_CanGrantOthers() public {
        _initAlice();

        vm.prank(alice);
        memory_.grantAccess(ALICE_ID, eve, IAgentMemory.AccessLevel.ADMIN, 0);

        // Eve (admin) can grant access to others
        vm.prank(eve);
        memory_.grantAccess(ALICE_ID, dave, IAgentMemory.AccessLevel.READ, 0);

        assertTrue(memory_.canRead(ALICE_ID, dave));
    }

    function test_GrantAccess_NonAdmin_CannotGrantAdmin() public {
        _initAlice();

        // Grant eve WRITE (not ADMIN)
        vm.prank(alice);
        memory_.grantAccess(ALICE_ID, eve, IAgentMemory.AccessLevel.WRITE, 0);

        // Eve tries to grant ADMIN — should fail
        vm.prank(eve);
        vm.expectRevert(IAgentMemory.CannotGrantHigherThanOwn.selector);
        memory_.grantAccess(ALICE_ID, dave, IAgentMemory.AccessLevel.ADMIN, 0);
    }

    function test_GrantAccess_WithExpiry_ExpiresCorrectly() public {
        _initAlice();
        uint256 expiry = block.timestamp + 1 hours;

        vm.prank(alice);
        memory_.grantAccess(ALICE_ID, dave, IAgentMemory.AccessLevel.READ, expiry);

        assertTrue(memory_.canRead(ALICE_ID, dave));

        // Warp past expiry
        vm.warp(block.timestamp + 2 hours);

        assertFalse(memory_.canRead(ALICE_ID, dave));
        assertEq(
            uint256(memory_.getAccessLevel(ALICE_ID, dave)),
            uint256(IAgentMemory.AccessLevel.NONE)
        );
    }

    function test_RevokeAccess_Success() public {
        _initAlice();

        vm.prank(alice);
        memory_.grantAccess(ALICE_ID, dave, IAgentMemory.AccessLevel.READ, 0);
        assertTrue(memory_.canRead(ALICE_ID, dave));

        vm.prank(alice);
        memory_.revokeAccess(ALICE_ID, dave);
        assertFalse(memory_.canRead(ALICE_ID, dave));
    }

    function test_RevokeAccess_EmitsEvent() public {
        _initAlice();
        vm.prank(alice);
        memory_.grantAccess(ALICE_ID, dave, IAgentMemory.AccessLevel.READ, 0);

        vm.expectEmit(true, true, false, false);
        emit IAgentMemory.AccessRevoked(ALICE_ID, dave);
        vm.prank(alice);
        memory_.revokeAccess(ALICE_ID, dave);
    }

    function test_GetAccessGrants_ReturnsAll() public {
        _initAlice();

        vm.startPrank(alice);
        memory_.grantAccess(ALICE_ID, dave, IAgentMemory.AccessLevel.READ, 0);
        memory_.grantAccess(ALICE_ID, eve, IAgentMemory.AccessLevel.WRITE, 0);
        vm.stopPrank();

        IAgentMemory.AccessGrant[] memory grants = memory_.getAccessGrants(ALICE_ID);
        assertEq(grants.length, 2);
    }

    // ============================================================
    //           AUTHORIZED WRITER TESTS (3 tests)
    // ============================================================

    function test_SetAuthorizedWriter_AddRemove() public {
        address newWriter = makeAddr("newWriter");
        assertFalse(memory_.isAuthorizedWriter(newWriter));

        vm.prank(protocolOwner);
        memory_.setAuthorizedWriter(newWriter, true);
        assertTrue(memory_.isAuthorizedWriter(newWriter));

        vm.prank(protocolOwner);
        memory_.setAuthorizedWriter(newWriter, false);
        assertFalse(memory_.isAuthorizedWriter(newWriter));
    }

    function test_SetAuthorizedWriter_Revert_NotOwner() public {
        vm.prank(charlie);
        vm.expectRevert(IAgentMemory.NotAuthorized.selector);
        memory_.setAuthorizedWriter(charlie, true);
    }

    function test_AuthorizedWriter_CanWriteAnyAgent() public {
        _initAlice();

        // Marketplace (authorized writer) can write even without explicit grant
        vm.prank(marketplace);
        uint256 v = memory_.writeMemory(
            ALICE_ID, IAgentMemory.MemoryType.TASK_HISTORY, CID_1, HASH_1
        );
        assertEq(v, 1);
    }

    // ============================================================
    //           INTEGRATION TESTS (4 tests)
    // ============================================================

    function test_Integration_AgentToAgentMemorySharing() public {
        _initAlice();

        vm.prank(protocolOwner);
        memory_.initializeAgent(BOB_ID, bob);

        // Alice writes her skills
        vm.prank(alice);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.SKILLS, CID_3, HASH_3);

        // Alice grants Bob READ access
        vm.prank(alice);
        memory_.grantAccess(ALICE_ID, bob, IAgentMemory.AccessLevel.READ, 0);

        // Bob can now read Alice's skills
        assertTrue(memory_.canRead(ALICE_ID, bob));

        IAgentMemory.MemorySnapshot memory snap = memory_.getLatestMemory(
            ALICE_ID, IAgentMemory.MemoryType.SKILLS
        );
        assertEq(snap.cid, CID_3);
    }

    function test_Integration_FullMemoryLifecycle() public {
        _initAlice();

        // Write context v1
        vm.prank(alice);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_1, HASH_1);

        // Marketplace updates task history
        vm.prank(marketplace);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.TASK_HISTORY, CID_2, HASH_2);

        // Alice updates context v2
        vm.prank(alice);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_2, HASH_2);

        // Latest context is v2
        IAgentMemory.MemorySnapshot memory ctx = memory_.getLatestMemory(
            ALICE_ID, IAgentMemory.MemoryType.CONTEXT
        );
        assertEq(ctx.version, 2);
        assertEq(ctx.cid, CID_2);

        // Archive v1
        vm.prank(alice);
        memory_.archiveMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, 1);

        // Total snapshots still 2 (archived not deleted)
        assertEq(memory_.getTotalSnapshots(ALICE_ID, IAgentMemory.MemoryType.CONTEXT), 2);
    }

    function test_Integration_TwoAgents_IsolatedMemory() public {
        _initAlice();
        vm.prank(protocolOwner);
        memory_.initializeAgent(BOB_ID, bob);

        vm.prank(alice);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.CONTEXT, CID_1, HASH_1);

        vm.prank(bob);
        memory_.writeMemory(BOB_ID, IAgentMemory.MemoryType.CONTEXT, CID_2, HASH_2);

        // Alice's memory is independent of Bob's
        assertEq(memory_.getCurrentVersion(ALICE_ID, IAgentMemory.MemoryType.CONTEXT), 1);
        assertEq(memory_.getCurrentVersion(BOB_ID, IAgentMemory.MemoryType.CONTEXT), 1);

        IAgentMemory.MemorySnapshot memory aliceCtx = memory_.getLatestMemory(
            ALICE_ID, IAgentMemory.MemoryType.CONTEXT
        );
        IAgentMemory.MemorySnapshot memory bobCtx = memory_.getLatestMemory(
            BOB_ID, IAgentMemory.MemoryType.CONTEXT
        );

        assertEq(aliceCtx.cid, CID_1);
        assertEq(bobCtx.cid, CID_2);
    }

    function test_Integration_WriteGrantRead_WorkflowComplete() public {
        _initAlice();

        // Protocol grants write to marketplace
        assertTrue(memory_.isAuthorizedWriter(marketplace));

        // Marketplace writes task history after task
        vm.prank(marketplace);
        memory_.writeMemory(ALICE_ID, IAgentMemory.MemoryType.TASK_HISTORY, CID_1, HASH_1);

        // Alice grants a collaborating agent READ
        vm.prank(alice);
        memory_.grantAccess(ALICE_ID, bob, IAgentMemory.AccessLevel.READ, 0);

        // Verify access chain
        assertTrue(memory_.canRead(ALICE_ID, alice));   // owner
        assertTrue(memory_.canRead(ALICE_ID, bob));     // granted
        assertFalse(memory_.canRead(ALICE_ID, charlie)); // unauthorized

        assertTrue(memory_.canWrite(ALICE_ID, alice));      // owner
        assertTrue(memory_.canWrite(ALICE_ID, marketplace)); // authorized writer
        assertFalse(memory_.canWrite(ALICE_ID, bob));       // read-only
        assertFalse(memory_.canWrite(ALICE_ID, charlie));   // unauthorized
    }

    // ============================================================
    //                   FUZZ TESTS (3 tests)
    // ============================================================

    function testFuzz_WriteMemory_VersionAlwaysIncreases(uint8 writes) public {
        vm.assume(writes > 0 && writes <= 20);
        _initAlice();

        vm.startPrank(alice);
        uint256 lastVersion = 0;
        for (uint256 i = 0; i < writes; i++) {
            uint256 v = memory_.writeMemory(
                ALICE_ID,
                IAgentMemory.MemoryType.CONTEXT,
                CID_1,
                keccak256(abi.encodePacked(i))
            );
            assertGt(v, lastVersion, "Version must always increase");
            lastVersion = v;
        }
        vm.stopPrank();

        assertEq(
            memory_.getCurrentVersion(ALICE_ID, IAgentMemory.MemoryType.CONTEXT),
            writes
        );
    }

    function testFuzz_AccessExpiry_Deterministic(uint256 expiry) public {
        vm.assume(expiry > block.timestamp + 1 && expiry < type(uint64).max);
        _initAlice();

        vm.prank(alice);
        memory_.grantAccess(ALICE_ID, dave, IAgentMemory.AccessLevel.READ, expiry);

        // Should be accessible before expiry
        assertTrue(memory_.canRead(ALICE_ID, dave));

        // After expiry, no access
        vm.warp(expiry + 1);
        assertFalse(memory_.canRead(ALICE_ID, dave));
    }

    function testFuzz_AllMemoryTypes_Independent(uint8 typeA, uint8 typeB) public {
        vm.assume(typeA < 6 && typeB < 6 && typeA != typeB);
        _initAlice();

        IAgentMemory.MemoryType mtA = IAgentMemory.MemoryType(typeA);
        IAgentMemory.MemoryType mtB = IAgentMemory.MemoryType(typeB);

        vm.startPrank(alice);
        memory_.writeMemory(ALICE_ID, mtA, CID_1, HASH_1);
        memory_.writeMemory(ALICE_ID, mtA, CID_2, HASH_2);
        memory_.writeMemory(ALICE_ID, mtB, CID_3, HASH_3);
        vm.stopPrank();

        assertEq(memory_.getCurrentVersion(ALICE_ID, mtA), 2);
        assertEq(memory_.getCurrentVersion(ALICE_ID, mtB), 1);
    }

    // ============================================================
    //                      HELPER
    // ============================================================

    function _initAlice() internal {
        vm.prank(protocolOwner);
        memory_.initializeAgent(ALICE_ID, alice);
    }
}
