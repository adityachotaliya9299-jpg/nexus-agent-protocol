// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IZKEscrow} from "./IZKEscrow.sol";
import {IGroth16Verifier} from "../zk/IGroth16Verifier.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title ZKEscrow
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice ZK-gated trustless escrow — payment releases on valid proof, not client approval.
///
/// @dev Security model:
///
///   COMMITMENT SCHEME (hide-then-reveal):
///     1. Client commits: commitment = keccak256(resultHash, salt)
///        → client knows what result they expect, but agent doesn't yet
///        → commitment is stored on-chain before task starts
///     2. Agent works off-chain, generates ZK proof of knowledge:
///        → Poseidon(secret, resultData) == resultHash
///        → this proves agent knows the data that produces the result
///     3. Agent submits: resultHash + salt + ZK proof
///     4. Contract checks: keccak256(resultHash, salt) == commitment ✓
///     5. Contract verifies: Groth16 proof valid ✓
///     6. → ETH released to agentWallet automatically
///
///   WHY THIS WORKS:
///     - Client can't withhold payment (no approval needed)
///     - Agent can't forge a proof (Groth16 is cryptographically sound)
///     - Neither party can manipulate the result hash (commitment is pre-set)
///     - No trusted arbitrator needed for clear-cut work
///
///   WHAT IT DOESN'T SOLVE:
///     - Disputes about whether the result was correct (quality)
///     - These still need the standard dispute flow → raiseDispute()
///     - Only eliminates disputes about whether work was done at all
///
///   FEE MODEL:
///     - No platform fee in ZKEscrow (trustless = no intermediary)
///     - Full amount goes to agent on valid proof
///     - Optional: protocol can take feeBps if set by owner
contract ZKEscrow is IZKEscrow, ReentrancyGuard {

    // ============================================================
    //                       CONSTANTS
    // ============================================================

    uint256 public constant MIN_DEADLINE = 1 hours;
    uint256 public constant MAX_DEADLINE = 90 days;
    uint256 public constant MAX_FEE_BPS  = 500; // Max 5% protocol fee

    // ============================================================
    //                         STORAGE
    // ============================================================

    address public immutable protocolOwner;
    address public immutable groth16Verifier;

    uint256 public override totalEscrows;
    uint256 public override totalReleased;

    uint256 public feeBps;       // Protocol fee (default 0)
    uint256 public accruedFees;  // Fees awaiting withdrawal
    address public arbitrator;   // For dispute resolution

    /// @notice escrowId => Escrow
    mapping(bytes32 => Escrow) private _escrows;

    /// @notice taskId => escrowId
    mapping(bytes32 => bytes32) private _taskEscrow;

    uint256 private _nonce;

    // ============================================================
    //                       MODIFIERS
    // ============================================================

    modifier onlyOwner() {
        if (msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    // ============================================================
    //                       CONSTRUCTOR
    // ============================================================

    constructor(
        address _protocolOwner,
        address _groth16Verifier,
        address _arbitrator
    ) {
        if (_protocolOwner == address(0) || _groth16Verifier == address(0) ||
            _arbitrator == address(0)) revert ZeroAddress();

        protocolOwner    = _protocolOwner;
        groth16Verifier  = _groth16Verifier;
        arbitrator       = _arbitrator;
    }

    // ============================================================
    //                    CREATE ESCROW
    // ============================================================

    /// @notice Client deposits ETH for a task, creating a ZK-gated escrow
    function createEscrow(
        bytes32 taskId,
        address payable agentWallet,
        uint256 deadline
    ) external payable override nonReentrant returns (bytes32 escrowId) {
        if (msg.value == 0) revert ZeroAmount();
        if (agentWallet == address(0)) revert ZeroAddress();
        if (deadline < block.timestamp + MIN_DEADLINE) revert InvalidDeadline();
        if (deadline > block.timestamp + MAX_DEADLINE) revert InvalidDeadline();

        escrowId = keccak256(abi.encodePacked(
            "zkescrow", msg.sender, taskId, _nonce++, block.timestamp
        ));

        _escrows[escrowId] = Escrow({
            escrowId:    escrowId,
            taskId:      taskId,
            client:      msg.sender,
            agentWallet: agentWallet,
            amount:      msg.value,
            commitment:  bytes32(0), // Set separately via setCommitment
            deadline:    deadline,
            createdAt:   block.timestamp,
            releasedAt:  0,
            status:      EscrowStatus.OPEN,
            proofId:     bytes32(0)
        });

        if (taskId != bytes32(0)) {
            _taskEscrow[taskId] = escrowId;
        }

        totalEscrows++;

        emit EscrowCreated(escrowId, taskId, msg.sender, msg.value, deadline);
    }

    // ============================================================
    //                    SET COMMITMENT
    // ============================================================

    /// @notice Client sets the expected result commitment
    /// @dev commitment = keccak256(abi.encodePacked(resultHash, salt))
    ///      Must be called BEFORE agent starts work — fixes what result is expected.
    function setCommitment(bytes32 escrowId, bytes32 commitment) external override {
        Escrow storage esc = _escrows[escrowId];
        if (esc.createdAt == 0) revert EscrowNotFound(escrowId);
        if (esc.status != EscrowStatus.OPEN) revert EscrowNotOpen(escrowId);
        if (esc.client != msg.sender) revert NotAuthorized();
        if (esc.commitment != bytes32(0)) revert CommitmentAlreadySet(escrowId);
        if (block.timestamp >= esc.deadline) revert DeadlinePassed(escrowId);

        esc.commitment = commitment;

        emit CommitmentSet(escrowId, commitment);
    }

    // ============================================================
    //                  RELEASE WITH ZK PROOF
    // ============================================================

    /// @notice Agent submits ZK proof to unlock payment — no client needed
    /// @param escrowId The escrow to release
    /// @param resultHash Hash of the completed work (Poseidon output)
    /// @param salt Random salt used in commitment (client shares off-chain)
    /// @param pA,pB,pC Groth16 proof components
    /// @param pubSignals Public signals: [resultHash, taskIdSignal]
    function releaseWithProof(
        bytes32 escrowId,
        bytes32 resultHash,
        bytes32 salt,
        uint256[2] calldata pA,
        uint256[2][2] calldata pB,
        uint256[2] calldata pC,
        uint256[2] calldata pubSignals
    ) external override nonReentrant {
        Escrow storage esc = _escrows[escrowId];
        if (esc.createdAt == 0) revert EscrowNotFound(escrowId);
        if (esc.status != EscrowStatus.OPEN) revert EscrowNotOpen(escrowId);
        if (esc.commitment == bytes32(0)) revert CommitmentNotSet(escrowId);
        if (block.timestamp > esc.deadline) revert DeadlinePassed(escrowId);

        // Step 1: Verify commitment matches
        bytes32 expectedCommitment = keccak256(abi.encodePacked(resultHash, salt));
        if (expectedCommitment != esc.commitment) revert CommitmentMismatch(escrowId);

        // Step 2: Verify Groth16 proof
        bool valid = IGroth16Verifier(groth16Verifier).verifyProof(pA, pB, pC, pubSignals);
        if (!valid) revert ProofVerificationFailed(escrowId);

        // Step 3: Release payment
        esc.status     = EscrowStatus.RELEASED;
        esc.releasedAt = block.timestamp;
        esc.proofId    = keccak256(abi.encodePacked(pA, pB, pC, pubSignals));

        uint256 total   = esc.amount;
        uint256 fee     = feeBps > 0 ? (total * feeBps) / 10000 : 0;
        uint256 payment = total - fee;
        accruedFees    += fee;
        totalReleased  += payment;

        emit ProofSubmitted(escrowId, esc.proofId);

        (bool ok,) = esc.agentWallet.call{value: payment}("");
        require(ok, "Payment failed");

        emit EscrowReleased(escrowId, esc.agentWallet, payment);
    }

    // ============================================================
    //                   REFUND AFTER DEADLINE
    // ============================================================

    /// @notice Client reclaims ETH if deadline passes with no valid proof
    function refundAfterDeadline(bytes32 escrowId) external override nonReentrant {
        Escrow storage esc = _escrows[escrowId];
        if (esc.createdAt == 0) revert EscrowNotFound(escrowId);
        if (esc.status != EscrowStatus.OPEN) revert EscrowNotOpen(escrowId);
        if (esc.client != msg.sender) revert NotAuthorized();
        if (block.timestamp <= esc.deadline) revert DeadlineNotPassed(escrowId);

        esc.status = EscrowStatus.REFUNDED;

        uint256 amount = esc.amount;
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "Refund failed");

        emit EscrowRefunded(escrowId, msg.sender, amount);
    }

    // ============================================================
    //                      RAISE DISPUTE
    // ============================================================

    /// @notice Either client or agentWallet raises a dispute for manual resolution
    function raiseDispute(bytes32 escrowId) external override {
        Escrow storage esc = _escrows[escrowId];
        if (esc.createdAt == 0) revert EscrowNotFound(escrowId);
        if (esc.status != EscrowStatus.OPEN) revert EscrowNotOpen(escrowId);

        bool isClient = msg.sender == esc.client;
        bool isAgent  = msg.sender == esc.agentWallet;
        if (!isClient && !isAgent) revert NotAuthorized();

        esc.status = EscrowStatus.DISPUTED;

        emit EscrowDisputed(escrowId);
    }

    // ============================================================
    //                     VIEW FUNCTIONS
    // ============================================================

    function getEscrow(bytes32 escrowId) external view override returns (Escrow memory) {
        if (_escrows[escrowId].createdAt == 0) revert EscrowNotFound(escrowId);
        return _escrows[escrowId];
    }

    function getTaskEscrow(bytes32 taskId) external view override returns (bytes32) {
        return _taskEscrow[taskId];
    }

    // ============================================================
    //                      ADMIN FUNCTIONS
    // ============================================================

    function setFeeBps(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= MAX_FEE_BPS, "Fee too high");
        feeBps = _feeBps;
    }

    function setArbitrator(address _arbitrator) external onlyOwner {
        if (_arbitrator == address(0)) revert ZeroAddress();
        arbitrator = _arbitrator;
    }

    function withdrawFees(address payable to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accruedFees;
        accruedFees = 0;
        (bool ok,) = to.call{value: amount}("");
        require(ok, "Withdrawal failed");
    }
}
