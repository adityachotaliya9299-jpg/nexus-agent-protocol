// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IZKEscrow
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Interface for ZK-gated trustless task escrow.
///
/// @dev Standard TaskMarketplace requires client to manually call approveWork().
///      ZKEscrow removes the client entirely from the payment path:
///
///      Flow:
///        1. Client deposits ETH into escrow for a specific task
///        2. Agent completes work off-chain
///        3. Agent generates Groth16 ZK proof:
///           - Proves they know the preimage of the committed result hash
///           - Proves the result hash matches what was committed at task start
///        4. Agent submits proof on-chain
///        5. Contract verifies proof via Groth16Verifier
///        6. If valid → ETH released automatically, no client approval needed
///        7. If invalid → proof rejected, ETH stays in escrow
///
///      This eliminates:
///        - Client ghost risk (client never approves, agent never gets paid)
///        - Dispute overhead for clear-cut work
///        - Trust requirement between client and agent
///
///      Commitment scheme:
///        At task creation: client submits commitment = keccak256(resultHash, salt)
///        At proof submission: agent reveals resultHash + ZK proof that they
///        know secret inputs that hash to resultHash via Poseidon
///        Contract verifies: Poseidon(secret, result) == resultHash AND commitment matches
interface IZKEscrow {

    // ============================================================
    //                         ENUMS
    // ============================================================

    enum EscrowStatus {
        OPEN,       // Waiting for proof submission
        RELEASED,   // Proof verified, funds paid out
        REFUNDED,   // Deadline passed, client refunded
        DISPUTED    // Manual dispute raised
    }

    // ============================================================
    //                         STRUCTS
    // ============================================================

    struct Escrow {
        bytes32 escrowId;
        bytes32 taskId;           // Linked marketplace task
        address client;
        address payable agentWallet; // Where payment goes on proof
        uint256 amount;
        bytes32 commitment;       // keccak256(resultHash, salt) — set by client
        uint256 deadline;
        uint256 createdAt;
        uint256 releasedAt;
        EscrowStatus status;
        bytes32 proofId;          // ZKVerifier proof ID on release
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event EscrowCreated(
        bytes32 indexed escrowId,
        bytes32 indexed taskId,
        address indexed client,
        uint256 amount,
        uint256 deadline
    );
    event CommitmentSet(bytes32 indexed escrowId, bytes32 commitment);
    event ProofSubmitted(bytes32 indexed escrowId, bytes32 indexed proofId);
    event EscrowReleased(bytes32 indexed escrowId, address indexed agentWallet, uint256 amount);
    event EscrowRefunded(bytes32 indexed escrowId, address indexed client, uint256 amount);
    event EscrowDisputed(bytes32 indexed escrowId);

    // ============================================================
    //                         ERRORS
    // ============================================================

    error NotAuthorized();
    error ZeroAddress();
    error ZeroAmount();
    error EscrowNotFound(bytes32 escrowId);
    error EscrowNotOpen(bytes32 escrowId);
    error DeadlineNotPassed(bytes32 escrowId);
    error DeadlinePassed(bytes32 escrowId);
    error CommitmentNotSet(bytes32 escrowId);
    error CommitmentAlreadySet(bytes32 escrowId);
    error CommitmentMismatch(bytes32 escrowId);
    error ProofVerificationFailed(bytes32 escrowId);
    error InvalidDeadline();

    // ============================================================
    //                     CORE FUNCTIONS
    // ============================================================

    /// @notice Client creates escrow for a task, depositing ETH
    function createEscrow(
        bytes32 taskId,
        address payable agentWallet,
        uint256 deadline
    ) external payable returns (bytes32 escrowId);

    /// @notice Client sets the result commitment (can be done after creation)
    /// @dev commitment = keccak256(abi.encodePacked(resultHash, salt))
    function setCommitment(bytes32 escrowId, bytes32 commitment) external;

    /// @notice Agent submits ZK proof to release escrow payment
    function releaseWithProof(
        bytes32 escrowId,
        bytes32 resultHash,
        bytes32 salt,
        uint256[2] calldata pA,
        uint256[2][2] calldata pB,
        uint256[2] calldata pC,
        uint256[2] calldata pubSignals
    ) external;

    /// @notice Client reclaims funds if deadline passed with no valid proof
    function refundAfterDeadline(bytes32 escrowId) external;

    /// @notice Either party raises a dispute for manual arbitration
    function raiseDispute(bytes32 escrowId) external;

    // ============================================================
    //                     VIEW FUNCTIONS
    // ============================================================

    function getEscrow(bytes32 escrowId) external view returns (Escrow memory);
    function getTaskEscrow(bytes32 taskId) external view returns (bytes32 escrowId);
    function totalEscrows() external view returns (uint256);
    function totalReleased() external view returns (uint256);
}
