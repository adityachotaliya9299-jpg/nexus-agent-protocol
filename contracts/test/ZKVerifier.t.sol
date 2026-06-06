// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ZKVerifier} from "../src/zk/ZKVerifier.sol";
import {IZKVerifier} from "../src/interfaces/IZKVerifier.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";
import {ReputationOracle} from "../src/reputation/ReputationOracle.sol";
import {IReputationOracle} from "../src/interfaces/IReputationOracle.sol";

contract ZKVerifierTest is Test {
    // ============================================================
    //                         SETUP
    // ============================================================

    ZKVerifier public verifier;
    AgentRegistry public registry;
    ReputationOracle public oracle;

    address public protocolOwner = makeAddr("protocolOwner");
    address public agentOwner    = makeAddr("agentOwner");
    address public agentOwner2   = makeAddr("agentOwner2");
    address public operator1     = makeAddr("operator1");
    address public operator2     = makeAddr("operator2");
    address public operator3     = makeAddr("operator3");
    address public stranger      = makeAddr("stranger");

    uint256 constant AGENT_ID_1 = 1;
    uint256 constant AGENT_ID_2 = 2;
    uint256 constant QUORUM     = 6700; // 67%

    bytes32 constant TASK_ID_1  = keccak256("task-1");
    bytes32 constant TASK_ID_2  = keccak256("task-2");

    // Valid proof data (first byte non-zero = passes simulation)
    bytes constant VALID_PROOF   = hex"deadbeefcafebabe0102030405060708090a0b0c0d0e0f101112131415161718";
    // Invalid proof data (first byte zero = fails simulation)
    bytes constant INVALID_PROOF = hex"00deadbeefcafebabe0102030405060708090a0b0c0d0e0f1011121314151617";

    bytes32 constant PUB_INPUT_HASH = keccak256("public-inputs");
    bytes  constant VK_DATA         = hex"aabbccddee112233445566778899aabb";

    bytes32 public vKeyId; // registered verification key

    string constant META = "ipfs://QmMeta";

    function setUp() public {
        // Deploy registry
        registry = new AgentRegistry(protocolOwner);

        vm.prank(agentOwner);
        registry.registerAgent(META, IAgentRegistry.AgentCategory.CODE);

        vm.prank(agentOwner2);
        registry.registerAgent(META, IAgentRegistry.AgentCategory.RESEARCH);

        // Deploy oracle
        oracle = new ReputationOracle(protocolOwner, address(registry));

        // Deploy verifier
        verifier = new ZKVerifier(
            protocolOwner,
            address(registry),
            address(oracle),
            QUORUM
        );

        // Authorize verifier in oracle
        vm.prank(protocolOwner);
        oracle.setAuthorizedUpdater(address(verifier), true);

        // Initialize reputations
        vm.startPrank(protocolOwner);
        oracle.initializeAgent(AGENT_ID_1);
        oracle.initializeAgent(AGENT_ID_2);
        vm.stopPrank();

        // Register a verification key
        vm.prank(protocolOwner);
        vKeyId = verifier.registerVerificationKey(
            IZKVerifier.ProofType.TASK_COMPLETION,
            VK_DATA
        );
    }

    // ============================================================
    //           DEPLOYMENT TESTS (4 tests)
    // ============================================================

    function test_Deploy_CorrectState() public view {
        assertEq(verifier.protocolOwner(), protocolOwner);
        assertEq(verifier.registry(), address(registry));
        assertEq(verifier.reputationOracle(), address(oracle));
        assertEq(verifier.quorumThreshold(), QUORUM);
        assertEq(verifier.totalProofsSubmitted(), 0);
        assertEq(verifier.totalProofsVerified(), 0);
    }

    function test_Deploy_Revert_ZeroOwner() public {
        vm.expectRevert(IZKVerifier.ZeroAddress.selector);
        new ZKVerifier(address(0), address(registry), address(oracle), QUORUM);
    }

    function test_Deploy_Revert_ZeroRegistry() public {
        vm.expectRevert(IZKVerifier.ZeroAddress.selector);
        new ZKVerifier(protocolOwner, address(0), address(oracle), QUORUM);
    }

    function test_Deploy_Revert_InvalidQuorum() public {
        vm.expectRevert(IZKVerifier.InvalidQuorumThreshold.selector);
        new ZKVerifier(protocolOwner, address(registry), address(oracle), 0);
    }

    // ============================================================
    //         VERIFICATION KEY TESTS (5 tests)
    // ============================================================

    function test_RegisterVKey_Success() public {
        vm.prank(protocolOwner);
        bytes32 keyId = verifier.registerVerificationKey(
            IZKVerifier.ProofType.CAPABILITY,
            hex"aabbccdd"
        );

        IZKVerifier.VerificationKey memory vk = verifier.getVerificationKey(keyId);
        assertEq(uint256(vk.proofType), uint256(IZKVerifier.ProofType.CAPABILITY));
        assertTrue(vk.isActive);
        assertEq(vk.registeredBy, protocolOwner);
    }

    function test_RegisterVKey_EmitsEvent() public {
        vm.prank(protocolOwner);
        vm.expectEmit(false, true, false, true);
        emit IZKVerifier.VerificationKeyRegistered(
            bytes32(0), IZKVerifier.ProofType.COMPUTATION, protocolOwner
        );
        verifier.registerVerificationKey(IZKVerifier.ProofType.COMPUTATION, hex"aabb");
    }

    function test_RegisterVKey_Revert_NotOwner() public {
        vm.prank(stranger);
        vm.expectRevert(IZKVerifier.NotAuthorized.selector);
        verifier.registerVerificationKey(IZKVerifier.ProofType.TASK_COMPLETION, hex"aabb");
    }

    function test_RevokeVKey_Success() public {
        vm.prank(protocolOwner);
        verifier.revokeVerificationKey(vKeyId);

        IZKVerifier.VerificationKey memory vk = verifier.getVerificationKey(vKeyId);
        assertFalse(vk.isActive);
    }

    function test_RevokeVKey_Revert_NotFound() public {
        vm.prank(protocolOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IZKVerifier.InvalidVerificationKey.selector, bytes32(0))
        );
        verifier.revokeVerificationKey(bytes32(0));
    }

    // ============================================================
    //           SUBMIT PROOF TESTS (8 tests)
    // ============================================================

    function test_SubmitProof_Success() public {
        vm.prank(agentOwner);
        bytes32 proofId = verifier.submitProof(
            AGENT_ID_1,
            IZKVerifier.ProofType.TASK_COMPLETION,
            TASK_ID_1,
            PUB_INPUT_HASH,
            VALID_PROOF,
            vKeyId
        );

        IZKVerifier.Proof memory proof = verifier.getProof(proofId);
        assertEq(proof.agentId, AGENT_ID_1);
        assertEq(uint256(proof.status), uint256(IZKVerifier.ProofStatus.PENDING));
        assertEq(proof.taskId, TASK_ID_1);
        assertEq(proof.publicInputHash, PUB_INPUT_HASH);
        assertEq(verifier.totalProofsSubmitted(), 1);
    }

    function test_SubmitProof_EmitsEvent() public {
        vm.expectEmit(false, true, true, false);
        emit IZKVerifier.ProofSubmitted(
            bytes32(0), AGENT_ID_1, IZKVerifier.ProofType.TASK_COMPLETION, TASK_ID_1
        );
        vm.prank(agentOwner);
        verifier.submitProof(
            AGENT_ID_1, IZKVerifier.ProofType.TASK_COMPLETION,
            TASK_ID_1, PUB_INPUT_HASH, VALID_PROOF, vKeyId
        );
    }

    function test_SubmitProof_TracksAgentProofs() public {
        vm.prank(agentOwner);
        bytes32 proofId = verifier.submitProof(
            AGENT_ID_1, IZKVerifier.ProofType.TASK_COMPLETION,
            TASK_ID_1, PUB_INPUT_HASH, VALID_PROOF, vKeyId
        );

        bytes32[] memory agentProofs = verifier.getAgentProofs(AGENT_ID_1);
        assertEq(agentProofs.length, 1);
        assertEq(agentProofs[0], proofId);
    }

    function test_SubmitProof_TracksTaskProofs() public {
        vm.prank(agentOwner);
        bytes32 proofId = verifier.submitProof(
            AGENT_ID_1, IZKVerifier.ProofType.TASK_COMPLETION,
            TASK_ID_1, PUB_INPUT_HASH, VALID_PROOF, vKeyId
        );

        bytes32[] memory taskProofs = verifier.getTaskProofs(TASK_ID_1);
        assertEq(taskProofs.length, 1);
        assertEq(taskProofs[0], proofId);
    }

    function test_SubmitProof_Revert_EmptyProofData() public {
        vm.prank(agentOwner);
        vm.expectRevert(IZKVerifier.InvalidProofData.selector);
        verifier.submitProof(
            AGENT_ID_1, IZKVerifier.ProofType.TASK_COMPLETION,
            TASK_ID_1, PUB_INPUT_HASH, "", vKeyId
        );
    }

    function test_SubmitProof_Revert_ZeroPublicInputHash() public {
        vm.prank(agentOwner);
        vm.expectRevert(IZKVerifier.InvalidProofData.selector);
        verifier.submitProof(
            AGENT_ID_1, IZKVerifier.ProofType.TASK_COMPLETION,
            TASK_ID_1, bytes32(0), VALID_PROOF, vKeyId
        );
    }

    function test_SubmitProof_Revert_InvalidVKey() public {
        vm.prank(agentOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IZKVerifier.InvalidVerificationKey.selector, bytes32(0))
        );
        verifier.submitProof(
            AGENT_ID_1, IZKVerifier.ProofType.TASK_COMPLETION,
            TASK_ID_1, PUB_INPUT_HASH, VALID_PROOF, bytes32(0)
        );
    }

    function test_SubmitProof_Revert_RevokedVKey() public {
        vm.prank(protocolOwner);
        verifier.revokeVerificationKey(vKeyId);

        vm.prank(agentOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IZKVerifier.KeyNotActive.selector, vKeyId)
        );
        verifier.submitProof(
            AGENT_ID_1, IZKVerifier.ProofType.TASK_COMPLETION,
            TASK_ID_1, PUB_INPUT_HASH, VALID_PROOF, vKeyId
        );
    }

    // ============================================================
    //           VERIFY PROOF TESTS (8 tests)
    // ============================================================

    function test_VerifyProof_ValidProof_ReturnsTrue() public {
        bytes32 proofId = _submitValidProof();

        vm.prank(protocolOwner);
        bool result = verifier.verifyProof(proofId);

        assertTrue(result);
        assertEq(uint256(verifier.getProof(proofId).status), uint256(IZKVerifier.ProofStatus.VERIFIED));
        assertEq(verifier.totalProofsVerified(), 1);
    }

    function test_VerifyProof_InvalidProof_ReturnsFalse() public {
        vm.prank(agentOwner);
        bytes32 proofId = verifier.submitProof(
            AGENT_ID_1, IZKVerifier.ProofType.TASK_COMPLETION,
            TASK_ID_1, PUB_INPUT_HASH, INVALID_PROOF, vKeyId
        );

        vm.prank(protocolOwner);
        bool result = verifier.verifyProof(proofId);

        assertFalse(result);
        assertEq(uint256(verifier.getProof(proofId).status), uint256(IZKVerifier.ProofStatus.REJECTED));
    }

    function test_VerifyProof_EmitsEvent() public {
        bytes32 proofId = _submitValidProof();

        vm.expectEmit(true, true, false, true);
        emit IZKVerifier.ProofVerified(proofId, AGENT_ID_1, true);
        vm.prank(protocolOwner);
        verifier.verifyProof(proofId);
    }

    function test_VerifyProof_Revert_NotFound() public {
        vm.prank(protocolOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IZKVerifier.ProofNotFound.selector, bytes32(0))
        );
        verifier.verifyProof(bytes32(0));
    }

    function test_VerifyProof_Revert_AlreadyVerified() public {
        bytes32 proofId = _submitValidProof();

        vm.prank(protocolOwner);
        verifier.verifyProof(proofId);

        vm.prank(protocolOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IZKVerifier.ProofAlreadyVerified.selector, proofId)
        );
        verifier.verifyProof(proofId);
    }

    function test_VerifyProof_Revert_Unauthorized() public {
        bytes32 proofId = _submitValidProof();

        vm.prank(stranger);
        vm.expectRevert("Not authorized to verify");
        verifier.verifyProof(proofId);
    }

    function test_VerifyProof_TaskCompletion_BoostsReputation() public {
        bytes32 proofId = _submitValidProof();
        uint256 scoreBefore = oracle.getScore(AGENT_ID_1);

        vm.prank(protocolOwner);
        verifier.verifyProof(proofId);

        assertGt(oracle.getScore(AGENT_ID_1), scoreBefore);
        assertTrue(verifier.getProof(proofId).reputationApplied);
    }

    function test_VerifyProof_Expired_ReturnsFalse() public {
        bytes32 proofId = _submitValidProof();

        // Warp past TTL
        vm.warp(block.timestamp + verifier.PROOF_TTL() + 1);

        vm.prank(protocolOwner);
        bool result = verifier.verifyProof(proofId);

        assertFalse(result);
        assertEq(
            uint256(verifier.getProof(proofId).status),
            uint256(IZKVerifier.ProofStatus.EXPIRED)
        );
    }

    // ============================================================
    //           BATCH VERIFY TESTS (4 tests)
    // ============================================================

    function test_BatchVerify_AllValid() public {
        bytes32 proofId1 = _submitValidProof();
        vm.prank(agentOwner);
        bytes32 proofId2 = verifier.submitProof(
            AGENT_ID_1, IZKVerifier.ProofType.CAPABILITY,
            bytes32(0), keccak256("inputs2"), VALID_PROOF, vKeyId
        );

        bytes32[] memory ids = new bytes32[](2);
        ids[0] = proofId1;
        ids[1] = proofId2;

        vm.prank(protocolOwner);
        bool[] memory results = verifier.batchVerifyProofs(ids);

        assertTrue(results[0]);
        assertTrue(results[1]);
        assertEq(verifier.totalProofsVerified(), 2);
    }

    function test_BatchVerify_MixedResults() public {
        bytes32 validId = _submitValidProof();
        vm.prank(agentOwner);
        bytes32 invalidId = verifier.submitProof(
            AGENT_ID_1, IZKVerifier.ProofType.COMPUTATION,
            bytes32(0), keccak256("pub"), INVALID_PROOF, vKeyId
        );

        bytes32[] memory ids = new bytes32[](2);
        ids[0] = validId;
        ids[1] = invalidId;

        vm.prank(protocolOwner);
        bool[] memory results = verifier.batchVerifyProofs(ids);

        assertTrue(results[0]);
        assertFalse(results[1]);
    }

    function test_BatchVerify_EmptyArray() public {
        bytes32[] memory ids = new bytes32[](0);
        vm.prank(protocolOwner);
        bool[] memory results = verifier.batchVerifyProofs(ids);
        assertEq(results.length, 0);
    }

    function test_BatchVerify_Revert_Unauthorized() public {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = bytes32(0);

        vm.prank(stranger);
        vm.expectRevert("Not authorized to verify");
        verifier.batchVerifyProofs(ids);
    }

    // ============================================================
    //           AVS OPERATOR TESTS (8 tests)
    // ============================================================

    function test_RegisterAVSOperator_Success() public {
        bytes32 opId = keccak256("operator-1");
        vm.prank(protocolOwner);
        verifier.registerAVSOperator(operator1, opId);

        assertTrue(verifier.isAVSOperator(operator1));
        assertEq(verifier.getOperatorCount(), 1);
    }

    function test_RegisterAVSOperator_EmitsEvent() public {
        bytes32 opId = keccak256("op");
        vm.expectEmit(true, false, false, true);
        emit IZKVerifier.AVSOperatorRegistered(operator1, opId);
        vm.prank(protocolOwner);
        verifier.registerAVSOperator(operator1, opId);
    }

    function test_RegisterAVSOperator_Revert_NotOwner() public {
        vm.prank(stranger);
        vm.expectRevert(IZKVerifier.NotAuthorized.selector);
        verifier.registerAVSOperator(operator1, keccak256("op"));
    }

    function test_RegisterAVSOperator_Revert_AlreadyRegistered() public {
        bytes32 opId = keccak256("op");
        vm.prank(protocolOwner);
        verifier.registerAVSOperator(operator1, opId);

        vm.prank(protocolOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IZKVerifier.OperatorAlreadyRegistered.selector, operator1)
        );
        verifier.registerAVSOperator(operator1, opId);
    }

    function test_DeregisterAVSOperator_Success() public {
        _registerOperators();
        assertEq(verifier.getOperatorCount(), 3);

        vm.prank(protocolOwner);
        verifier.deregisterAVSOperator(operator1);

        assertFalse(verifier.isAVSOperator(operator1));
        assertEq(verifier.getOperatorCount(), 2);
    }

    function test_DeregisterAVSOperator_Revert_NotRegistered() public {
        vm.prank(protocolOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IZKVerifier.OperatorNotRegistered.selector, operator1)
        );
        verifier.deregisterAVSOperator(operator1);
    }

    function test_AVSOperator_CanVerifyProof() public {
        _registerOperators();
        bytes32 proofId = _submitValidProof();

        // Operator can call verifyProof
        vm.prank(operator1);
        bool result = verifier.verifyProof(proofId);
        assertTrue(result);
    }

    function test_SetQuorumThreshold_Success() public {
        vm.prank(protocolOwner);
        verifier.setQuorumThreshold(5000);
        assertEq(verifier.quorumThreshold(), 5000);
    }

    // ============================================================
    //           AVS RESPONSE / QUORUM TESTS (7 tests)
    // ============================================================

    function test_DispatchToAVS_Success() public {
        bytes32 proofId = _submitValidProof();

        vm.prank(protocolOwner);
        verifier.dispatchToAVS(proofId);
        // No revert = success; AVS task created
    }

    function test_DispatchToAVS_EmitsEvent() public {
        bytes32 proofId = _submitValidProof();

        vm.expectEmit(false, true, false, false);
        emit IZKVerifier.AVSTaskCreated(bytes32(0), proofId);
        vm.prank(protocolOwner);
        verifier.dispatchToAVS(proofId);
    }

    function test_AVSResponse_QuorumReached_Verifies() public {
        _registerOperators(); // 3 operators, quorum=67%

        // Lower quorum to 33% so 1 out of 3 triggers it
        vm.prank(protocolOwner);
        verifier.setQuorumThreshold(3300);

        bytes32 proofId = _submitValidProof();

        vm.prank(protocolOwner);
        verifier.dispatchToAVS(proofId);
        bytes32 avsTaskId = keccak256(abi.encodePacked(proofId, block.timestamp));

        // Submit one positive response (33% of 3)
        vm.prank(operator1);
        verifier.submitAVSResponse(avsTaskId, true, "");

        // Verify quorum was NOT reached yet (only 1/3 = 33%, threshold = 33%)
        // Actually 3300/10000 = 33% threshold, 1/3 responses = 33%
        // So quorum IS reached → proof verified
        assertEq(
            uint256(verifier.getProof(proofId).status),
            uint256(IZKVerifier.ProofStatus.VERIFIED)
        );
    }

    function test_AVSResponse_NegativeMajority_Rejects() public {
        _registerOperators();

        // Set quorum to 33% so 1 response triggers finalization
        vm.prank(protocolOwner);
        verifier.setQuorumThreshold(3300);

        bytes32 proofId = _submitValidProof();

        vm.prank(protocolOwner);
        verifier.dispatchToAVS(proofId);
        bytes32 avsTaskId = keccak256(abi.encodePacked(proofId, block.timestamp));

        // Submit negative response
        vm.prank(operator1);
        verifier.submitAVSResponse(avsTaskId, false, "");

        assertEq(
            uint256(verifier.getProof(proofId).status),
            uint256(IZKVerifier.ProofStatus.REJECTED)
        );
    }

    function test_AVSResponse_Revert_NotOperator() public {
        bytes32 proofId = _submitValidProof();

        vm.prank(protocolOwner);
        verifier.dispatchToAVS(proofId);
        bytes32 avsTaskId = keccak256(abi.encodePacked(proofId, block.timestamp));

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IZKVerifier.OperatorNotRegistered.selector, stranger)
        );
        verifier.submitAVSResponse(avsTaskId, true, "");
    }

    function test_AVSResponse_BeforeQuorum_StaysPending() public {
        _registerOperators(); // 3 operators, quorum=67%

        bytes32 proofId = _submitValidProof();

        vm.prank(protocolOwner);
        verifier.dispatchToAVS(proofId);
        bytes32 avsTaskId = keccak256(abi.encodePacked(proofId, block.timestamp));

        // Only 1 response out of 3 = 33%, below 67% quorum
        vm.prank(operator1);
        verifier.submitAVSResponse(avsTaskId, true, "");

        // Should still be PENDING
        assertEq(
            uint256(verifier.getProof(proofId).status),
            uint256(IZKVerifier.ProofStatus.PENDING)
        );
    }

    function test_AVSResponse_MultipleOperators_QuorumReached() public {
        _registerOperators(); // 3 operators, quorum=67%

        bytes32 proofId = _submitValidProof();

        vm.prank(protocolOwner);
        verifier.dispatchToAVS(proofId);
        bytes32 avsTaskId = keccak256(abi.encodePacked(proofId, block.timestamp));

        // 2 out of 3 = 67% = quorum reached
        vm.prank(operator1);
        verifier.submitAVSResponse(avsTaskId, true, "");

        vm.prank(operator2);
        verifier.submitAVSResponse(avsTaskId, true, "");

        assertEq(
            uint256(verifier.getProof(proofId).status),
            uint256(IZKVerifier.ProofStatus.VERIFIED)
        );
    }

    // ============================================================
    //           INTEGRATION TESTS (5 tests)
    // ============================================================

    function test_Integration_ProofVerification_BoostsReputation() public {
        uint256 scoreBefore = oracle.getScore(AGENT_ID_1);

        bytes32 proofId = _submitValidProof();
        vm.prank(protocolOwner);
        verifier.verifyProof(proofId);

        assertGt(oracle.getScore(AGENT_ID_1), scoreBefore);
    }

    function test_Integration_MultipleProofsPerAgent() public {
        // Register capability vkey
        vm.prank(protocolOwner);
        bytes32 capVKeyId = verifier.registerVerificationKey(
            IZKVerifier.ProofType.CAPABILITY, hex"ccddee"
        );

        vm.startPrank(agentOwner);
        bytes32 p1 = verifier.submitProof(
            AGENT_ID_1, IZKVerifier.ProofType.TASK_COMPLETION,
            TASK_ID_1, PUB_INPUT_HASH, VALID_PROOF, vKeyId
        );
        bytes32 p2 = verifier.submitProof(
            AGENT_ID_1, IZKVerifier.ProofType.CAPABILITY,
            bytes32(0), keccak256("cap-inputs"), VALID_PROOF, capVKeyId
        );
        vm.stopPrank();

        assertEq(verifier.getAgentProofs(AGENT_ID_1).length, 2);

        vm.prank(protocolOwner);
        verifier.verifyProof(p1);
        vm.prank(protocolOwner);
        verifier.verifyProof(p2);

        assertTrue(verifier.isProofValid(p1));
        assertTrue(verifier.isProofValid(p2));
    }

    function test_Integration_ProofNotValid_BeforeVerification() public {
        bytes32 proofId = _submitValidProof();
        assertFalse(verifier.isProofValid(proofId)); // PENDING = not valid
    }

    function test_Integration_TaskWithMultipleProofs() public {
        vm.prank(agentOwner);
        bytes32 p1 = verifier.submitProof(
            AGENT_ID_1, IZKVerifier.ProofType.TASK_COMPLETION,
            TASK_ID_1, PUB_INPUT_HASH, VALID_PROOF, vKeyId
        );
        vm.prank(agentOwner2);
        bytes32 p2 = verifier.submitProof(
            AGENT_ID_2, IZKVerifier.ProofType.TASK_COMPLETION,
            TASK_ID_1, keccak256("inputs2"), VALID_PROOF, vKeyId
        );

        bytes32[] memory taskProofs = verifier.getTaskProofs(TASK_ID_1);
        assertEq(taskProofs.length, 2);
        assertEq(taskProofs[0], p1);
        assertEq(taskProofs[1], p2);
    }

    function test_Integration_FullAVSFlow_ThreeOperators() public {
        _registerOperators();

        bytes32 proofId = _submitValidProof();

        vm.prank(protocolOwner);
        verifier.dispatchToAVS(proofId);
        bytes32 avsTaskId = keccak256(abi.encodePacked(proofId, block.timestamp));

        uint256 scoreBefore = oracle.getScore(AGENT_ID_1);

        // All 3 operators vote positive
        vm.prank(operator1);
        verifier.submitAVSResponse(avsTaskId, true, "");
        vm.prank(operator2);
        verifier.submitAVSResponse(avsTaskId, true, "");
        // After 2/3 = 67% quorum reached, proof verified

        assertTrue(verifier.isProofValid(proofId));
        assertGt(oracle.getScore(AGENT_ID_1), scoreBefore);
    }

    // ============================================================
    //                   FUZZ TESTS (4 tests)
    // ============================================================

    function testFuzz_SubmitProof_UniqueIds(uint8 count) public {
        vm.assume(count > 1 && count <= 10);

        bytes32[] memory ids = new bytes32[](count);
        for (uint256 i = 0; i < count; i++) {
            vm.prank(agentOwner);
            ids[i] = verifier.submitProof(
                AGENT_ID_1,
                IZKVerifier.ProofType.TASK_COMPLETION,
                bytes32(i),
                keccak256(abi.encodePacked(i)),
                VALID_PROOF,
                vKeyId
            );
        }

        // All IDs must be unique
        for (uint256 i = 0; i < count; i++) {
            for (uint256 j = i + 1; j < count; j++) {
                assertTrue(ids[i] != ids[j], "Duplicate proofId");
            }
        }
    }

    function testFuzz_QuorumThreshold_ValidRange(uint256 threshold) public {
        vm.assume(threshold >= 1 && threshold <= 100);
        vm.prank(protocolOwner);
        verifier.setQuorumThreshold(threshold);
        assertEq(verifier.quorumThreshold(), threshold);
    }

    function testFuzz_ProofTTL_Enforced(uint256 warpSeconds) public {
        vm.assume(warpSeconds > verifier.PROOF_TTL());
        vm.assume(warpSeconds < 365 days * 10);

        bytes32 proofId = _submitValidProof();

        vm.warp(block.timestamp + warpSeconds);

        vm.prank(protocolOwner);
        bool result = verifier.verifyProof(proofId);
        assertFalse(result);
        assertEq(
            uint256(verifier.getProof(proofId).status),
            uint256(IZKVerifier.ProofStatus.EXPIRED)
        );
    }

    function testFuzz_VKey_DifferentProofTypes(uint8 typeIdx) public {
        vm.assume(typeIdx < 4);
        IZKVerifier.ProofType pt = IZKVerifier.ProofType(typeIdx);

        vm.prank(protocolOwner);
        bytes32 keyId = verifier.registerVerificationKey(pt, hex"aabbcc");

        IZKVerifier.VerificationKey memory vk = verifier.getVerificationKey(keyId);
        assertEq(uint256(vk.proofType), uint256(pt));
        assertTrue(vk.isActive);
    }

    // ============================================================
    //                      HELPERS
    // ============================================================

    function _submitValidProof() internal returns (bytes32) {
        vm.prank(agentOwner);
        return verifier.submitProof(
            AGENT_ID_1,
            IZKVerifier.ProofType.TASK_COMPLETION,
            TASK_ID_1,
            PUB_INPUT_HASH,
            VALID_PROOF,
            vKeyId
        );
    }

    function _registerOperators() internal {
        vm.startPrank(protocolOwner);
        verifier.registerAVSOperator(operator1, keccak256("op1"));
        verifier.registerAVSOperator(operator2, keccak256("op2"));
        verifier.registerAVSOperator(operator3, keccak256("op3"));
        vm.stopPrank();
    }
}
