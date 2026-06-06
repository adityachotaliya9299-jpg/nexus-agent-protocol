// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IZKVerifier
/// @author Aditya Chotaliya [adityachotaliya.vercel.app]
/// @notice Interface for ZK proof verification of agent task completions
/// @dev Agents can submit zkProofs to prove:
///      - Task was completed correctly (without revealing inputs)
///      - Computation was performed honestly
///      - Agent has certain capabilities (without revealing model weights)
///
///      Proof types:
///        TASK_COMPLETION  - Proves agent completed task per spec
///        CAPABILITY       - Proves agent has a skill/qualification
///        COMPUTATION      - Proves a specific computation was run correctly
///        IDENTITY         - Proves agent identity without revealing private keys
///
///      Verification flow:
///        1. Agent completes task off-chain
///        2. Agent generates zkProof using their proving key
///        3. Agent submits proof on-chain via submitProof()
///        4. Verifier checks proof against verification key
///        5. If valid: reputation boost + proof stored on-chain
///        6. TaskMarketplace can query proofs before releasing payment
interface IZKVerifier {
    // ============================================================
    //                         ENUMS
    // ============================================================

    enum ProofType {
        TASK_COMPLETION,  // Proves task was done correctly
        CAPABILITY,       // Proves agent capability/skill
        COMPUTATION,      // Proves honest computation
        IDENTITY          // Proves agent identity
    }

    enum ProofStatus {
        PENDING,    // Submitted, not yet verified
        VERIFIED,   // Successfully verified
        REJECTED,   // Verification failed
        EXPIRED     // Proof TTL passed
    }

    // ============================================================
    //                         STRUCTS
    // ============================================================

    struct Proof {
        bytes32 proofId;
        uint256 agentId;
        ProofType proofType;
        ProofStatus status;
        bytes32 taskId;           // Linked task (bytes32(0) if capability proof)
        bytes32 publicInputHash;  // Hash of public inputs
        bytes proofData;          // The actual ZK proof bytes
        bytes32 verificationKey;  // Which vKey was used
        address submittedBy;
        uint256 submittedAt;
        uint256 verifiedAt;
        bool reputationApplied;
    }

    struct VerificationKey {
        bytes32 keyId;
        ProofType proofType;
        bytes keyData;            // The actual verification key
        bool isActive;
        address registeredBy;
        uint256 registeredAt;
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event ProofSubmitted(
        bytes32 indexed proofId,
        uint256 indexed agentId,
        ProofType indexed proofType,
        bytes32 taskId
    );

    event ProofVerified(
        bytes32 indexed proofId,
        uint256 indexed agentId,
        bool success
    );

    event ProofRejected(bytes32 indexed proofId, string reason);

    event VerificationKeyRegistered(
        bytes32 indexed keyId,
        ProofType indexed proofType,
        address registeredBy
    );

    event VerificationKeyRevoked(bytes32 indexed keyId);

    event AVSOperatorRegistered(address indexed operator, bytes32 operatorId);

    event AVSOperatorDeregistered(address indexed operator);

    event AVSTaskCreated(bytes32 indexed avsTaskId, bytes32 indexed proofId);

    event AVSResponseReceived(bytes32 indexed avsTaskId, bool quorumReached);

    // ============================================================
    //                         ERRORS
    // ============================================================

    error ProofNotFound(bytes32 proofId);
    error ProofAlreadyVerified(bytes32 proofId);
    error ProofAlreadySubmitted(bytes32 proofId);
    error InvalidProofData();
    error InvalidVerificationKey(bytes32 keyId);
    error KeyNotActive(bytes32 keyId);
    error AgentNotRegistered(uint256 agentId);
    error NotAuthorized();
    error ZeroAddress();
    error QuorumNotReached(bytes32 avsTaskId);
    error OperatorAlreadyRegistered(address operator);
    error OperatorNotRegistered(address operator);
    error InvalidQuorumThreshold();

    // ============================================================
    //                     CORE FUNCTIONS
    // ============================================================

    function submitProof(
        uint256 agentId,
        ProofType proofType,
        bytes32 taskId,
        bytes32 publicInputHash,
        bytes calldata proofData,
        bytes32 verificationKeyId
    ) external returns (bytes32 proofId);

    function verifyProof(bytes32 proofId) external returns (bool success);

    function batchVerifyProofs(bytes32[] calldata proofIds) external returns (bool[] memory results);

    // ============================================================
    //                  VERIFICATION KEY MANAGEMENT
    // ============================================================

    function registerVerificationKey(
        ProofType proofType,
        bytes calldata keyData
    ) external returns (bytes32 keyId);

    function revokeVerificationKey(bytes32 keyId) external;

    // ============================================================
    //                   AVS OPERATOR MANAGEMENT
    // ============================================================

    function registerAVSOperator(address operator, bytes32 operatorId) external;

    function deregisterAVSOperator(address operator) external;

    function submitAVSResponse(
        bytes32 avsTaskId,
        bool proofValid,
        bytes calldata operatorSignature
    ) external;

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    function getProof(bytes32 proofId) external view returns (Proof memory);

    function getAgentProofs(uint256 agentId) external view returns (bytes32[] memory);

    function getTaskProofs(bytes32 taskId) external view returns (bytes32[] memory);

    function getVerificationKey(bytes32 keyId) external view returns (VerificationKey memory);

    function isProofValid(bytes32 proofId) external view returns (bool);

    function isAVSOperator(address operator) external view returns (bool);

    function getOperatorCount() external view returns (uint256);

    function quorumThreshold() external view returns (uint256);

    function totalProofsSubmitted() external view returns (uint256);

    function totalProofsVerified() external view returns (uint256);
}
