// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IZKVerifier} from "../interfaces/IZKVerifier.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";
import {IReputationOracle} from "../interfaces/IReputationOracle.sol";
import {Groth16ProofLib} from "./Groth16ProofLib.sol";

/// @title ZKVerifier
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice ZK proof verification system with EigenLayer AVS operator network
///
/// @dev Architecture:
///
///   ON-CHAIN VERIFICATION (simple mode):
///     - Protocol registers verification keys for each proof type
///     - Agent submits proof + public inputs
///     - Contract verifies via Groth16/PLONK (simulated in this phase)
///     - Valid proof → reputation boost + stored on-chain
///
///   AVS-ASSISTED VERIFICATION (decentralized mode):
///     - EigenLayer AVS operators receive proof verification tasks
///     - Operators run off-chain verification and sign responses
///     - Once quorum reached (e.g. 2/3 operators agree), result is finalized
///     - This scales to complex proofs that are too expensive on-chain
///
///   Reputation integration:
///     - TASK_COMPLETION proof verified → DISPUTE_WON-equivalent boost
///     - CAPABILITY proof verified → stored for marketplace filtering
///     - Failed verification → no change (not penalized for bad proofs)
///
///   Note: Full ZK proof verification (Groth16/PLONK) requires precompiles
///   or libraries. This contract implements the verification framework
///   with simulated verification — real crypto plugs in at the library level.

contract ZKVerifier is IZKVerifier {

    using Groth16ProofLib for Groth16ProofLib.Proof;

    /// @notice Emitted when a real Groth16 proof is verified on-chain
    event Groth16ProofVerified(bytes32 indexed proofId, uint256 indexed agentId, uint256 taskIdSignal);

    /// @notice Emitted when the Groth16 verifier address is updated
    event Groth16VerifierSet(address indexed verifier);
    // ============================================================
    //                       CONSTANTS
    // ============================================================

    uint256 public constant MAX_PROOF_SIZE    = 10_000; // bytes
    uint256 public constant PROOF_TTL         = 30 days;
    uint256 public constant MIN_QUORUM        = 1;
    uint256 public constant MAX_QUORUM        = 10000;
    uint256 public constant REPUTATION_BOOST  = 200;    // bp boost for verified proof

    // ============================================================
    //                         STORAGE
    // ============================================================

    address public immutable protocolOwner;
    address public immutable registry;
    address public immutable reputationOracle;

    /// @notice The deployed snarkjs-generated Groth16Verifier (real ZK verification)
    address public groth16Verifier;

    /// @notice Quorum threshold — % of AVS operators needed to finalize (basis points)
    uint256 public override quorumThreshold;

    uint256 public override totalProofsSubmitted;
    uint256 public override totalProofsVerified;

    /// @notice proofId => Proof
    mapping(bytes32 => Proof) private _proofs;

    /// @notice agentId => list of proofIds
    mapping(uint256 => bytes32[]) private _agentProofs;

    /// @notice taskId => list of proofIds
    mapping(bytes32 => bytes32[]) private _taskProofs;

    /// @notice keyId => VerificationKey
    mapping(bytes32 => VerificationKey) private _verificationKeys;

    /// @notice AVS operator address => operatorId
    mapping(address => bytes32) private _avsOperators;

    /// @notice List of all registered AVS operators
    address[] private _operatorList;

    /// @notice avsTaskId => operator address => their vote
    mapping(bytes32 => mapping(address => bool)) private _avsResponses;

    /// @notice avsTaskId => number of responses received
    mapping(bytes32 => uint256) private _avsResponseCount;

    /// @notice avsTaskId => number of positive votes
    mapping(bytes32 => uint256) private _avsPositiveVotes;

    /// @notice avsTaskId => linked proofId
    mapping(bytes32 => bytes32) private _avsTaskToProof;

    /// @notice proofId => avsTaskId (if dispatched to AVS)
    mapping(bytes32 => bytes32) private _proofToAVSTask;

    /// @notice nonce for proofId generation
    uint256 private _proofNonce;

    // ============================================================
    //                       MODIFIERS
    // ============================================================

    modifier onlyProtocolOwner() {
        if (msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    modifier onlyAVSOperator() {
        if (_avsOperators[msg.sender] == bytes32(0)) revert OperatorNotRegistered(msg.sender);
        _;
    }

    // ============================================================
    //                       CONSTRUCTOR
    // ============================================================

    constructor(
        address _protocolOwner,
        address _registry,
        address _reputationOracle,
        uint256 _quorumThreshold
    ) {
        if (_protocolOwner == address(0) || _registry == address(0) ||
            _reputationOracle == address(0)) revert ZeroAddress();
        if (_quorumThreshold < MIN_QUORUM || _quorumThreshold > MAX_QUORUM) {
            revert InvalidQuorumThreshold();
        }

        protocolOwner    = _protocolOwner;
        registry         = _registry;
        reputationOracle = _reputationOracle;
        quorumThreshold  = _quorumThreshold;
    }

    // ============================================================
    //                      SUBMIT PROOF
    // ============================================================

    /// @notice Agent submits a ZK proof for verification
    function submitProof(
        uint256 agentId,
        ProofType proofType,
        bytes32 taskId,
        bytes32 publicInputHash,
        bytes calldata proofData,
        bytes32 verificationKeyId
    ) external override returns (bytes32 proofId) {
        // Validate agent exists
        IAgentRegistry(registry).getAgent(agentId); // reverts if not found

        if (proofData.length == 0 || proofData.length > MAX_PROOF_SIZE) revert InvalidProofData();
        if (publicInputHash == bytes32(0)) revert InvalidProofData();

        // Verify key is registered and active
        VerificationKey storage vKey = _verificationKeys[verificationKeyId];
        if (vKey.registeredAt == 0) revert InvalidVerificationKey(verificationKeyId);
        if (!vKey.isActive) revert KeyNotActive(verificationKeyId);

        // Generate unique proofId
        proofId = keccak256(abi.encodePacked(agentId, _proofNonce++, block.timestamp, proofData));

        if (_proofs[proofId].submittedAt != 0) revert ProofAlreadySubmitted(proofId);

        _proofs[proofId] = Proof({
            proofId: proofId,
            agentId: agentId,
            proofType: proofType,
            status: ProofStatus.PENDING,
            taskId: taskId,
            publicInputHash: publicInputHash,
            proofData: proofData,
            verificationKey: verificationKeyId,
            submittedBy: msg.sender,
            submittedAt: block.timestamp,
            verifiedAt: 0,
            reputationApplied: false
        });

        _agentProofs[agentId].push(proofId);
        if (taskId != bytes32(0)) {
            _taskProofs[taskId].push(proofId);
        }

        totalProofsSubmitted++;

        emit ProofSubmitted(proofId, agentId, proofType, taskId);
    }

    // ============================================================
    //                      VERIFY PROOF
    // ============================================================

    /// @notice Verify a submitted proof on-chain
    /// @dev In production: calls Groth16/PLONK verifier with the vKey
    ///      Here: protocol owner or authorized verifier confirms validity
    ///      (AVS operators will replace this in decentralized mode)
    function verifyProof(bytes32 proofId) external override returns (bool success) {
        // Only protocol owner or AVS operators can verify
        require(
            msg.sender == protocolOwner || _avsOperators[msg.sender] != bytes32(0),
            "Not authorized to verify"
        );

        Proof storage proof = _proofs[proofId];
        if (proof.submittedAt == 0) revert ProofNotFound(proofId);
        if (proof.status == ProofStatus.VERIFIED) revert ProofAlreadyVerified(proofId);

        // Check TTL
        if (block.timestamp > proof.submittedAt + PROOF_TTL) {
            proof.status = ProofStatus.EXPIRED;
            return false;
        }

        // Simulate verification: in production, call actual ZK verifier library
        // Real implementation: IGroth16Verifier(verifier).verifyProof(vKey, pubInputs, proofData)
        success = _simulateVerification(proof);

        if (success) {
            proof.status = ProofStatus.VERIFIED;
            proof.verifiedAt = block.timestamp;
            totalProofsVerified++;

            // Apply reputation boost for task completion proofs
            if (!proof.reputationApplied &&
                proof.proofType == ProofType.TASK_COMPLETION) {
                proof.reputationApplied = true;
                _applyReputationBoost(proof.agentId, proof.taskId);
            }
        } else {
            proof.status = ProofStatus.REJECTED;
        }

        emit ProofVerified(proofId, proof.agentId, success);
    }

    /// @notice Batch verify multiple proofs in one call
    function batchVerifyProofs(bytes32[] calldata proofIds)
        external
        override
        returns (bool[] memory results)
    {
        require(
            msg.sender == protocolOwner || _avsOperators[msg.sender] != bytes32(0),
            "Not authorized to verify"
        );

        results = new bool[](proofIds.length);
        for (uint256 i = 0; i < proofIds.length; i++) {
            Proof storage proof = _proofs[proofIds[i]];
            if (proof.submittedAt == 0 || proof.status == ProofStatus.VERIFIED) {
                results[i] = proof.status == ProofStatus.VERIFIED;
                continue;
            }

            bool valid = _simulateVerification(proof);
            if (valid) {
                proof.status = ProofStatus.VERIFIED;
                proof.verifiedAt = block.timestamp;
                totalProofsVerified++;
                if (!proof.reputationApplied && proof.proofType == ProofType.TASK_COMPLETION) {
                    proof.reputationApplied = true;
                    _applyReputationBoost(proof.agentId, proof.taskId);
                }
            } else {
                proof.status = ProofStatus.REJECTED;
            }
            results[i] = valid;
            emit ProofVerified(proofIds[i], proof.agentId, valid);
        }
    }

    // ============================================================
    //                  VERIFICATION KEY MANAGEMENT
    // ============================================================

    function registerVerificationKey(ProofType proofType, bytes calldata keyData)
        external
        override
        onlyProtocolOwner
        returns (bytes32 keyId)
    {
        if (keyData.length == 0) revert InvalidProofData();

        keyId = keccak256(abi.encodePacked(proofType, keyData, block.timestamp));

        _verificationKeys[keyId] = VerificationKey({
            keyId: keyId,
            proofType: proofType,
            keyData: keyData,
            isActive: true,
            registeredBy: msg.sender,
            registeredAt: block.timestamp
        });

        emit VerificationKeyRegistered(keyId, proofType, msg.sender);
    }

    function revokeVerificationKey(bytes32 keyId)
        external
        override
        onlyProtocolOwner
    {
        if (_verificationKeys[keyId].registeredAt == 0) {
            revert InvalidVerificationKey(keyId);
        }
        _verificationKeys[keyId].isActive = false;
        emit VerificationKeyRevoked(keyId);
    }

    // ============================================================
    //                   AVS OPERATOR MANAGEMENT
    // ============================================================

    function registerAVSOperator(address operator, bytes32 operatorId)
        external
        override
        onlyProtocolOwner
    {
        if (operator == address(0)) revert ZeroAddress();
        if (_avsOperators[operator] != bytes32(0)) revert OperatorAlreadyRegistered(operator);

        _avsOperators[operator] = operatorId;
        _operatorList.push(operator);

        emit AVSOperatorRegistered(operator, operatorId);
    }

    function deregisterAVSOperator(address operator)
        external
        override
        onlyProtocolOwner
    {
        if (_avsOperators[operator] == bytes32(0)) revert OperatorNotRegistered(operator);
        delete _avsOperators[operator];

        // Remove from list
        for (uint256 i = 0; i < _operatorList.length; i++) {
            if (_operatorList[i] == operator) {
                _operatorList[i] = _operatorList[_operatorList.length - 1];
                _operatorList.pop();
                break;
            }
        }

        emit AVSOperatorDeregistered(operator);
    }

    /// @notice AVS operator submits their verification response
    function submitAVSResponse(
        bytes32 avsTaskId,
        bool proofValid,
        bytes calldata /*operatorSignature*/
    ) external override onlyAVSOperator {
        bytes32 proofId = _avsTaskToProof[avsTaskId];
        if (proofId == bytes32(0)) revert ProofNotFound(avsTaskId);

        // Record response
        _avsResponses[avsTaskId][msg.sender] = proofValid;
        _avsResponseCount[avsTaskId]++;
        if (proofValid) _avsPositiveVotes[avsTaskId]++;

        // Check if quorum reached
        uint256 totalOperators = _operatorList.length;
        if (totalOperators == 0) return;

        uint256 responsePct = (_avsResponseCount[avsTaskId] * 10000) / totalOperators;

        if (responsePct >= quorumThreshold) {
            // Quorum reached — finalize
            uint256 positivePct = (_avsPositiveVotes[avsTaskId] * 10000) /
                _avsResponseCount[avsTaskId];
            bool finalResult = positivePct >= 5000; // Majority positive

            Proof storage proof = _proofs[proofId];
            if (proof.status == ProofStatus.PENDING) {
                proof.status = finalResult ? ProofStatus.VERIFIED : ProofStatus.REJECTED;
                if (finalResult) {
                    proof.verifiedAt = block.timestamp;
                    totalProofsVerified++;
                    if (!proof.reputationApplied &&
                        proof.proofType == ProofType.TASK_COMPLETION) {
                        proof.reputationApplied = true;
                        _applyReputationBoost(proof.agentId, proof.taskId);
                    }
                }
                emit ProofVerified(proofId, proof.agentId, finalResult);
            }

            emit AVSResponseReceived(avsTaskId, finalResult);
        }
    }

    /// @notice Dispatch a proof to the AVS network for decentralized verification
    function dispatchToAVS(bytes32 proofId) external onlyProtocolOwner {
        Proof storage proof = _proofs[proofId];
        if (proof.submittedAt == 0) revert ProofNotFound(proofId);
        if (proof.status != ProofStatus.PENDING) revert ProofAlreadyVerified(proofId);

        bytes32 avsTaskId = keccak256(abi.encodePacked(proofId, block.timestamp));
        _avsTaskToProof[avsTaskId] = proofId;
        _proofToAVSTask[proofId] = avsTaskId;

        emit AVSTaskCreated(avsTaskId, proofId);
    }

    /// @notice Update quorum threshold
    function setQuorumThreshold(uint256 newThreshold) external onlyProtocolOwner {
        if (newThreshold < MIN_QUORUM || newThreshold > MAX_QUORUM) {
            revert InvalidQuorumThreshold();
        }
        quorumThreshold = newThreshold;
    }

    // ============================================================
    //              REAL GROTH16 VERIFICATION (Phase 9)
    // ============================================================

    /// @notice Set the deployed Groth16Verifier contract address
    /// @dev Generated by snarkjs and deployed separately. Once set,
    ///      submitProofWithGroth16 performs real on-chain verification.
    function setGroth16Verifier(address _verifier) external onlyProtocolOwner {
        if (_verifier == address(0)) revert ZeroAddress();
        groth16Verifier = _verifier;
        emit Groth16VerifierSet(_verifier);
    }

    /// @notice Submit a proof that is verified with REAL on-chain Groth16 math.
    /// @dev Unlike submitProof (which stores for later AVS/owner verification),
    ///      this verifies immediately and trustlessly via the Groth16Verifier.
    ///      No human, no operator, no simulation — pure cryptographic verification.
    /// @param agentId The agent claiming task completion
    /// @param taskId The task being proven complete
    /// @param proof The Groth16 proof + public signals [taskId, outputHash]
    /// @return proofId The stored proof identifier
    /// @return verified True if the proof cryptographically verified
    function submitProofWithGroth16(
        uint256 agentId,
        bytes32 taskId,
        Groth16ProofLib.Proof calldata proof
    ) external returns (bytes32 proofId, bool verified) {
        // Verifier must be configured
        if (groth16Verifier == address(0)) revert InvalidVerificationKey(bytes32(0));

        // Validate agent exists
        IAgentRegistry(registry).getAgent(agentId); // reverts if not found

        // Replay protection: the proof's public taskId signal must match
        // the taskId being claimed. Prevents reusing a valid proof on another task.
        uint256 taskIdSignal = proof.pubSignals[0];
        require(taskIdSignal == uint256(taskId), "Proof taskId mismatch");

        // ── REAL CRYPTOGRAPHIC VERIFICATION ──
        verified = Groth16ProofLib.verify(groth16Verifier, proof);

        // Generate unique proofId
        proofId = keccak256(
            abi.encodePacked(agentId, _proofNonce++, block.timestamp, proof.pubSignals[1])
        );

        _proofs[proofId] = Proof({
            proofId: proofId,
            agentId: agentId,
            proofType: ProofType.TASK_COMPLETION,
            status: verified ? ProofStatus.VERIFIED : ProofStatus.REJECTED,
            taskId: taskId,
            publicInputHash: bytes32(proof.pubSignals[1]), // outputHash
            proofData: abi.encode(proof.a, proof.b, proof.c),
            verificationKey: bytes32(uint256(uint160(groth16Verifier))),
            submittedBy: msg.sender,
            submittedAt: block.timestamp,
            verifiedAt: verified ? block.timestamp : 0,
            reputationApplied: false
        });

        _agentProofs[agentId].push(proofId);
        if (taskId != bytes32(0)) {
            _taskProofs[taskId].push(proofId);
        }

        totalProofsSubmitted++;

        emit ProofSubmitted(proofId, agentId, ProofType.TASK_COMPLETION, taskId);

        if (verified) {
            totalProofsVerified++;
            _proofs[proofId].reputationApplied = true;
            _applyReputationBoost(agentId, taskId);
            emit Groth16ProofVerified(proofId, agentId, taskIdSignal);
            emit ProofVerified(proofId, agentId, true);
        } else {
            emit ProofVerified(proofId, agentId, false);
        }
    }

    // ============================================================
    //                     INTERNAL HELPERS
    // ============================================================

    /// @notice Simulates ZK proof verification
    /// @dev In production: replace with actual Groth16/PLONK verifier call
    ///      Real: IGroth16Verifier.verifyProof(vKey, publicInputs, proof)
    ///      Returns true if proofData is non-trivial and publicInputHash matches
    function _simulateVerification(Proof storage proof) internal view returns (bool) {
        // Basic sanity checks that a real verifier would also do
        if (proof.proofData.length < 32) return false;
        if (proof.publicInputHash == bytes32(0)) return false;
        if (!_verificationKeys[proof.verificationKey].isActive) return false;

        // In real implementation: call Groth16Verifier.verifyProof()
        // For testing: proof is valid if first byte of proofData is non-zero
        return uint8(proof.proofData[0]) != 0;
    }

    function _applyReputationBoost(uint256 agentId, bytes32 taskId) internal {
        try IReputationOracle(reputationOracle).updateReputation(
            agentId,
            IReputationOracle.UpdateReason.DISPUTE_WON, // Closest equivalent
            taskId
        ) {} catch {}
    }

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    function getProof(bytes32 proofId) external view override returns (Proof memory) {
        if (_proofs[proofId].submittedAt == 0) revert ProofNotFound(proofId);
        return _proofs[proofId];
    }

    function getAgentProofs(uint256 agentId) external view override returns (bytes32[] memory) {
        return _agentProofs[agentId];
    }

    function getTaskProofs(bytes32 taskId) external view override returns (bytes32[] memory) {
        return _taskProofs[taskId];
    }

    function getVerificationKey(bytes32 keyId)
        external view override returns (VerificationKey memory)
    {
        if (_verificationKeys[keyId].registeredAt == 0) revert InvalidVerificationKey(keyId);
        return _verificationKeys[keyId];
    }

    function isProofValid(bytes32 proofId) external view override returns (bool) {
        return _proofs[proofId].status == ProofStatus.VERIFIED;
    }

    function isAVSOperator(address operator) external view override returns (bool) {
        return _avsOperators[operator] != bytes32(0);
    }

    function getOperatorCount() external view override returns (uint256) {
        return _operatorList.length;
    }
}
