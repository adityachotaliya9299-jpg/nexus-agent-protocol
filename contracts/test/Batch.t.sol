// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ResultStorage} from "../src/storage/ResultStorage.sol";
import {IResultStorage} from "../src/storage/IResultStorage.sol";
import {AgentDAO} from "../src/dao/AgentDAO.sol";
import {IAgentDAO} from "../src/dao/IAgentDAO.sol";
import {CommunityGrants} from "../src/grants/CommunityGrants.sol";
import {ICommunityGrants} from "../src/grants/ICommunityGrants.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";

// ── Stubs ──────────────────────────────────────────────────────

contract MockRegistry {
    mapping(uint256 => address) public owners;
    mapping(uint256 => bool)    public exists;
    uint256 public agentCount;

    function addAgent(uint256 id, address owner) external {
        owners[id] = owner; exists[id] = true; agentCount++;
    }

    function getAgent(uint256 id) external view returns (IAgentRegistry.AgentProfile memory p) {
        require(exists[id], "not found");
        p.agentId = id; p.owner = owners[id];
        p.status  = IAgentRegistry.AgentStatus.ACTIVE;
        return p;
    }

    function totalAgents() external view returns (uint256) { return agentCount; }
}

contract MockOracle {
    mapping(uint256 => uint256) public scores;
    function setScore(uint256 id, uint256 s) external { scores[id] = s; }
    function getScore(uint256 id) external view returns (uint256) {
        return scores[id] == 0 ? 5000 : scores[id];
    }
}

// ── ResultStorage Tests ────────────────────────────────────────

contract ResultStorageTest is Test {
    ResultStorage internal store;
    MockRegistry  internal registry;

    address constant OWNER   = address(0xA11CE);
    address constant AGENT1  = address(0xA6E41);
    address constant STRANGER = address(0x577);

    uint256 constant AGENT_ID = 1;
    bytes32 constant TASK_ID  = bytes32(uint256(0xBEEF));
    string  constant ARWEAVE_TX = "xTc3oml9vxM6eK8U0kT-FYwFZDi8JEhOi3NKpMhY2Lk"; // 43 chars

    function setUp() public {
        registry = new MockRegistry();
        registry.addAgent(AGENT_ID, AGENT1);

        vm.prank(OWNER);
        store = new ResultStorage(OWNER, address(registry));
    }

    function test_Anchor_Success() public {
        vm.prank(AGENT1);
        store.anchorResult(
            TASK_ID, AGENT_ID, ARWEAVE_TX,
            keccak256("result"), 1024, "application/json"
        );

        IResultStorage.StoredResult memory r = store.getResult(TASK_ID);
        assertEq(r.arweaveTxId, ARWEAVE_TX);
        assertEq(r.agentId, AGENT_ID);
        assertFalse(r.verified);
        assertEq(store.totalAnchored(), 1);
    }

    function test_Anchor_EmitsEvent() public {
        bytes32 hash = keccak256("result");
        vm.expectEmit(true, true, false, true);
        emit IResultStorage.ResultAnchored(TASK_ID, AGENT_ID, ARWEAVE_TX, hash);
        vm.prank(AGENT1);
        store.anchorResult(TASK_ID, AGENT_ID, ARWEAVE_TX, hash, 1024, "application/json");
    }

    function test_Anchor_Duplicate_Reverts() public {
        vm.prank(AGENT1);
        store.anchorResult(TASK_ID, AGENT_ID, ARWEAVE_TX, keccak256("r"), 1024, "text/plain");

        vm.prank(AGENT1);
        vm.expectRevert(abi.encodeWithSelector(IResultStorage.ResultAlreadyAnchored.selector, TASK_ID));
        store.anchorResult(TASK_ID, AGENT_ID, ARWEAVE_TX, keccak256("r"), 1024, "text/plain");
    }

    function test_Anchor_InvalidTxId_Reverts() public {
        vm.prank(AGENT1);
        vm.expectRevert(); // InvalidArweaveTxId
        store.anchorResult(TASK_ID, AGENT_ID, "short", keccak256("r"), 0, "");
    }

    function test_Anchor_NotOwner_Reverts() public {
        vm.prank(STRANGER);
        vm.expectRevert(IResultStorage.NotAuthorized.selector);
        store.anchorResult(TASK_ID, AGENT_ID, ARWEAVE_TX, keccak256("r"), 0, "");
    }

    function test_Verify_Success() public {
        bytes32 hash = keccak256("result content");
        vm.prank(AGENT1);
        store.anchorResult(TASK_ID, AGENT_ID, ARWEAVE_TX, hash, 1024, "text/plain");

        store.verifyResult(TASK_ID, hash);
        assertTrue(store.getResult(TASK_ID).verified);
    }

    function test_Verify_WrongHash_Reverts() public {
        vm.prank(AGENT1);
        store.anchorResult(TASK_ID, AGENT_ID, ARWEAVE_TX, keccak256("real"), 0, "");

        vm.expectRevert(); // HashMismatch
        store.verifyResult(TASK_ID, keccak256("fake"));
    }

    function test_IsAnchored_BeforeAndAfter() public {
        assertFalse(store.isAnchored(TASK_ID));
        vm.prank(AGENT1);
        store.anchorResult(TASK_ID, AGENT_ID, ARWEAVE_TX, keccak256("r"), 0, "");
        assertTrue(store.isAnchored(TASK_ID));
    }

    function test_GetAgentResults_TracksAll() public {
        bytes32 taskId2 = bytes32(uint256(0xCAFE));
        string memory arweave2 = "aB3cD4eF5gH6iJ7kL8mN9oP0qR1sT2uV3wX4yZ5aB6";

        vm.prank(AGENT1);
        store.anchorResult(TASK_ID, AGENT_ID, ARWEAVE_TX, keccak256("r1"), 0, "");
        vm.prank(AGENT1);
        store.anchorResult(taskId2, AGENT_ID, arweave2, keccak256("r2"), 0, "");

        bytes32[] memory results = store.getAgentResults(AGENT_ID);
        assertEq(results.length, 2);
    }

    function testFuzz_ArweaveTxId_Exactly43Chars(string calldata id) public {
        vm.assume(bytes(id).length == 43);
        // May or may not be valid base64url — just test no panic
        vm.prank(AGENT1);
        try store.anchorResult(TASK_ID, AGENT_ID, id, keccak256("r"), 0, "") {} catch {}
    }
}

// ── AgentDAO Tests ─────────────────────────────────────────────

contract AgentDAOTest is Test {
    AgentDAO     internal dao;
    MockRegistry internal registry;

    address constant OWNER   = address(0xA11CE);
    address constant A1      = address(0x1111);
    address constant A2      = address(0x2222);
    address constant A3      = address(0x3333);

    uint256 constant ID1 = 1;
    uint256 constant ID2 = 2;
    uint256 constant ID3 = 3;

    bytes32 constant TASK_ID = bytes32(uint256(0xBEEF));

    function setUp() public {
        registry = new MockRegistry();
        registry.addAgent(ID1, A1);
        registry.addAgent(ID2, A2);
        registry.addAgent(ID3, A3);

        vm.prank(OWNER);
        dao = new AgentDAO(OWNER, address(registry));

        vm.deal(A1, 10 ether);
        vm.deal(A2, 10 ether);
    }

    function _createDAO() internal returns (bytes32 daoId) {
        uint256[] memory ids  = new uint256[](2);
        uint256[] memory bps  = new uint256[](2);
        ids[0] = ID1; ids[1] = ID2;
        bps[0] = 6000; bps[1] = 4000;

        vm.prank(A1);
        return dao.createDAO("TestDAO", ids, bps);
    }

    function test_CreateDAO_Success() public {
        bytes32 id = _createDAO();
        IAgentDAO.DAOInfo memory info = dao.getDAO(id);
        assertEq(info.name, "TestDAO");
        assertEq(info.totalMembers, 2);
        assertTrue(info.isActive);
        assertEq(dao.totalDAOs(), 1);
    }

    function test_CreateDAO_InvalidSplitTotal_Reverts() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory bps = new uint256[](2);
        ids[0] = ID1; ids[1] = ID2;
        bps[0] = 5000; bps[1] = 4000; // sum = 9000, not 10000

        vm.prank(A1);
        vm.expectRevert(abi.encodeWithSelector(IAgentDAO.InvalidSplitTotal.selector, 9000));
        dao.createDAO("BadDAO", ids, bps);
    }

    function test_IsMember_TrueForMembers() public {
        bytes32 id = _createDAO();
        assertTrue(dao.isMember(id, ID1));
        assertTrue(dao.isMember(id, ID2));
        assertFalse(dao.isMember(id, ID3));
    }

    function test_ProposeTask_Success() public {
        bytes32 daoId = _createDAO();
        vm.prank(A1);
        bytes32 propId = dao.proposeTask(daoId, TASK_ID, ID1);
        IAgentDAO.TaskProposal memory p = dao.getProposal(propId);
        assertEq(p.taskId, TASK_ID);
        assertEq(uint256(p.status), uint256(IAgentDAO.ProposalStatus.PENDING));
    }

    function test_Vote_Success() public {
        bytes32 daoId  = _createDAO();
        vm.prank(A1);
        bytes32 propId = dao.proposeTask(daoId, TASK_ID, ID1);

        vm.prank(A1);
        dao.vote(propId, ID1, true);
        vm.prank(A2);
        dao.vote(propId, ID2, true);

        IAgentDAO.TaskProposal memory p = dao.getProposal(propId);
        assertEq(p.forVotes, 2);
    }

    function test_Vote_Twice_Reverts() public {
        bytes32 daoId  = _createDAO();
        vm.prank(A1);
        bytes32 propId = dao.proposeTask(daoId, TASK_ID, ID1);

        vm.prank(A1);
        dao.vote(propId, ID1, true);

        vm.prank(A1);
        vm.expectRevert(abi.encodeWithSelector(IAgentDAO.AlreadyVoted.selector, propId, ID1));
        dao.vote(propId, ID1, true);
    }

    function test_Execute_PassesWith_Majority() public {
        bytes32 daoId  = _createDAO();
        vm.prank(A1);
        bytes32 propId = dao.proposeTask(daoId, TASK_ID, ID1);

        vm.prank(A1);
        dao.vote(propId, ID1, true);
        vm.prank(A2);
        dao.vote(propId, ID2, true);

        vm.warp(block.timestamp + 25 hours);
        dao.executeProposal(propId);

        assertEq(uint256(dao.getProposal(propId).status),
            uint256(IAgentDAO.ProposalStatus.ACCEPTED));
    }

    function test_DistributeRevenue_SplitsCorrectly() public {
        bytes32 daoId = _createDAO();
        uint256 bal1Before = A1.balance;
        uint256 bal2Before = A2.balance;

        dao.distributeRevenue{value: 1 ether}(daoId, TASK_ID);

        assertEq(A1.balance, bal1Before + 0.6 ether); // 6000 bps
        assertEq(A2.balance, bal2Before + 0.4 ether); // 4000 bps
    }

    function testFuzz_Revenue_SplitConservesETH(uint96 amount) public {
        vm.assume(amount > 0);
        bytes32 daoId = _createDAO();
        vm.deal(address(this), amount);

        uint256 a1Before = A1.balance;
        uint256 a2Before = A2.balance;

        dao.distributeRevenue{value: amount}(daoId, TASK_ID);

        uint256 totalReceived = (A1.balance - a1Before) + (A2.balance - a2Before);
        assertEq(totalReceived, amount);
    }
}

// ── CommunityGrants Tests ──────────────────────────────────────

contract CommunityGrantsTest is Test {
    CommunityGrants internal grants;
    MockRegistry    internal registry;
    MockOracle      internal oracle;

    address constant OWNER     = address(0xA11CE);
    address constant PROPOSER  = address(0xA6E41);
    address constant VOTER1    = address(0xV0071);
    address constant RECIPIENT = address(0x9EC1);
    address constant STRANGER  = address(0x577);

    uint256 constant AGENT1 = 1;
    uint256 constant AGENT2 = 2;

    function setUp() public {
        registry = new MockRegistry();
        oracle   = new MockOracle();

        registry.addAgent(AGENT1, PROPOSER);
        registry.addAgent(AGENT2, VOTER1);
        oracle.setScore(AGENT1, 8000);
        oracle.setScore(AGENT2, 6000);

        vm.prank(OWNER);
        grants = new CommunityGrants(OWNER, address(registry), address(oracle));

        vm.deal(address(grants), 10 ether);
        vm.deal(PROPOSER,        1 ether);
        vm.deal(VOTER1,          1 ether);
    }

    function test_Deposit_Success() public {
        vm.deal(address(this), 1 ether);
        grants.deposit{value: 1 ether}("marketplace");
        assertEq(grants.totalDeposited(), 1 ether);
    }

    function test_ProposeGrant_Success() public {
        vm.prank(PROPOSER);
        bytes32 id = grants.proposeGrant(
            "Build Nexus Explorer",
            "A block explorer for Nexus Protocol",
            RECIPIENT, 1 ether,
            ICommunityGrants.GrantType.ECOSYSTEM, AGENT1
        );

        ICommunityGrants.Grant memory g = grants.getGrant(id);
        assertEq(g.title, "Build Nexus Explorer");
        assertEq(g.amount, 1 ether);
        assertEq(uint256(g.status), uint256(ICommunityGrants.GrantStatus.VOTING));
        assertEq(grants.totalGrants(), 1);
    }

    function test_ProposeGrant_NotOwner_Reverts() public {
        vm.prank(STRANGER);
        vm.expectRevert(); // NotAuthorized or agent not found
        grants.proposeGrant("T", "D", RECIPIENT, 1 ether,
            ICommunityGrants.GrantType.DEVELOPMENT, AGENT1);
    }

    function test_Vote_Success() public {
        vm.prank(PROPOSER);
        bytes32 id = grants.proposeGrant("T", "D", RECIPIENT, 0.5 ether,
            ICommunityGrants.GrantType.ECOSYSTEM, AGENT1);

        vm.prank(PROPOSER);
        grants.voteOnGrant(id, AGENT1, true);

        ICommunityGrants.Grant memory g = grants.getGrant(id);
        assertEq(g.forVotes, 8000); // rep score of AGENT1
    }

    function test_Vote_Twice_Reverts() public {
        vm.prank(PROPOSER);
        bytes32 id = grants.proposeGrant("T", "D", RECIPIENT, 0.5 ether,
            ICommunityGrants.GrantType.ECOSYSTEM, AGENT1);

        vm.prank(PROPOSER);
        grants.voteOnGrant(id, AGENT1, true);

        vm.prank(PROPOSER);
        vm.expectRevert(abi.encodeWithSelector(ICommunityGrants.AlreadyVoted.selector, id, AGENT1));
        grants.voteOnGrant(id, AGENT1, true);
    }

    function test_FullGrantCycle() public {
        vm.prank(PROPOSER);
        bytes32 id = grants.proposeGrant("T", "D", RECIPIENT, 0.5 ether,
            ICommunityGrants.GrantType.ECOSYSTEM, AGENT1);

        // Vote FOR
        vm.prank(PROPOSER);
        grants.voteOnGrant(id, AGENT1, true);
        vm.prank(VOTER1);
        grants.voteOnGrant(id, AGENT2, true);

        // Finalize after voting ends
        vm.warp(block.timestamp + 3 days + 1);
        grants.finalizeGrant(id);
        assertEq(uint256(grants.getGrant(id).status),
            uint256(ICommunityGrants.GrantStatus.APPROVED));

        // Execute after timelock
        vm.warp(block.timestamp + 24 hours + 1);
        uint256 balBefore = RECIPIENT.balance;
        grants.executeGrant(id);

        assertEq(RECIPIENT.balance, balBefore + 0.5 ether);
        assertEq(uint256(grants.getGrant(id).status),
            uint256(ICommunityGrants.GrantStatus.EXECUTED));
        assertEq(grants.totalGranted(), 0.5 ether);
    }

    function test_Execute_InsufficientBalance_Reverts() public {
        vm.prank(PROPOSER);
        bytes32 id = grants.proposeGrant("T", "D", RECIPIENT, 100 ether,
            ICommunityGrants.GrantType.ECOSYSTEM, AGENT1);

        vm.prank(PROPOSER);
        grants.voteOnGrant(id, AGENT1, true);
        vm.prank(VOTER1);
        grants.voteOnGrant(id, AGENT2, true);

        vm.warp(block.timestamp + 3 days + 1);
        grants.finalizeGrant(id);

        vm.warp(block.timestamp + 24 hours + 1);
        vm.expectRevert(); // InsufficientTreasury
        grants.executeGrant(id);
    }

    function test_GetActiveGrants_ReturnsOnlyActive() public {
        vm.prank(PROPOSER);
        grants.proposeGrant("G1", "D", RECIPIENT, 0.1 ether,
            ICommunityGrants.GrantType.ECOSYSTEM, AGENT1);

        assertEq(grants.getActiveGrants().length, 1);
    }

    function test_Receive_ETH() public {
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(grants).call{value: 1 ether}("");
        assertTrue(ok);
        assertGe(address(grants).balance, 1 ether);
    }
}
