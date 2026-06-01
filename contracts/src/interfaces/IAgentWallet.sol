// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAgentWallet
/// @notice Interface for the ERC-4337 smart wallet owned by each AI agent
/// @dev Every agent gets exactly one AgentWallet. It can:
///      - Receive ETH and ERC-20 tokens (earnings from tasks)
///      - Execute arbitrary calls (agent actions on-chain)
///      - Sign UserOperations via the ERC-4337 EntryPoint
///      - Pay for its own gas (acts as its own paymaster optionally)
interface IAgentWallet {
    // ============================================================
    //                         STRUCTS
    // ============================================================

    /// @notice Packed ERC-4337 UserOperation (simplified for reference)
    struct UserOperation {
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes paymasterAndData;
        bytes signature;
    }

    /// @notice A single call to execute
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event WalletInitialized(
        address indexed owner,
        address indexed entryPoint,
        uint256 indexed agentId
    );

    event ExecutedCall(
        address indexed target,
        uint256 value,
        bytes data,
        bool success
    );

    event ExecutedBatch(uint256 callCount, bool allSucceeded);

    event ETHReceived(address indexed from, uint256 amount);

    event ERC20Withdrawn(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    event ETHWithdrawn(address indexed to, uint256 amount);

    event GuardianSet(address indexed guardian, bool authorized);

    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    // ============================================================
    //                         ERRORS
    // ============================================================

    error NotOwnerOrEntryPoint();
    error NotEntryPoint();
    error CallFailed(address target, bytes returnData);
    error InsufficientBalance(uint256 requested, uint256 available);
    error ZeroAddress();
    error AlreadyInitialized();
    error InvalidSignature();
    error NotGuardian();

    // ============================================================
    //                    EXECUTION FUNCTIONS
    // ============================================================

    /// @notice Execute a single call — the agent's core action primitive
    function execute(address target, uint256 value, bytes calldata data) external;

    /// @notice Execute multiple calls atomically in one UserOp
    function executeBatch(Call[] calldata calls) external;

    // ============================================================
    //                    WALLET MANAGEMENT
    // ============================================================

    function withdrawETH(address payable to, uint256 amount) external;

    function withdrawERC20(address token, address to, uint256 amount) external;

    function setGuardian(address guardian, bool authorized) external;

    function transferOwnership(address newOwner) external;

    // ============================================================
    //                     ERC-4337 FUNCTIONS
    // ============================================================

    /// @notice Validate a UserOperation — called by EntryPoint
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData);

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    function owner() external view returns (address);

    function entryPoint() external view returns (address);

    function agentId() external view returns (uint256);

    function nonce() external view returns (uint256);

    function isGuardian(address guardian) external view returns (bool);

    function getBalance() external view returns (uint256);
}
