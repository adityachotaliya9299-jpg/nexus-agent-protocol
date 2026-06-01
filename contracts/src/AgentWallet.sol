// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentWallet} from "./interfaces/IAgentWallet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title AgentWallet
/// @author Nexus Agent Protocol
/// @notice ERC-4337 compatible smart contract wallet for autonomous AI agents
///
/// @dev Architecture:
///   - Each AI agent owns exactly one AgentWallet
///   - The wallet is deployed by AgentWalletFactory via CREATE2
///   - Owner = the agent controller EOA (or another agent in future)
///   - Supports single calls, batched calls, ETH/ERC-20 management
///   - ERC-4337: validates UserOps via ECDSA signature from owner
///   - Guardian system: recovery addresses for the agent wallet
///
/// Security properties:
///   - Only owner OR EntryPoint can execute calls
///   - Only owner can withdraw funds or change settings
///   - Nonce prevents UserOp replay attacks
///   - Reentrancy guard on execute functions
///   - Initialized flag prevents re-initialization
///
/// ERC-4337 flow:
///   Bundler -> EntryPoint.handleOps() -> wallet.validateUserOp() -> wallet.execute()
contract AgentWallet is IAgentWallet {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // ============================================================
    //                         CONSTANTS
    // ============================================================

    /// @notice ERC-4337 validation success return value
    uint256 private constant SIG_VALIDATION_SUCCESS = 0;

    /// @notice ERC-4337 validation failure return value
    uint256 private constant SIG_VALIDATION_FAILED = 1;

    // ============================================================
    //                         STORAGE
    // ============================================================

    /// @notice The EOA that controls this wallet (agent operator)
    address private _owner;

    /// @notice The ERC-4337 EntryPoint contract
    address private immutable _entryPoint;

    /// @notice The AgentRegistry contract (for linking back)
    address private immutable _registry;

    /// @notice The agent's on-chain ID
    uint256 private _agentId;

    /// @notice Anti-replay nonce for UserOperations
    uint256 private _nonce;

    /// @notice Whether this wallet has been initialized
    bool private _initialized;

    /// @notice Reentrancy lock
    bool private _locked;

    /// @notice Guardian addresses — can trigger recovery
    mapping(address => bool) private _guardians;

    // ============================================================
    //                       MODIFIERS
    // ============================================================

    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwnerOrEntryPoint();
        _;
    }

    modifier onlyOwnerOrEntryPoint() {
        if (msg.sender != _owner && msg.sender != _entryPoint) {
            revert NotOwnerOrEntryPoint();
        }
        _;
    }

    modifier onlyEntryPoint() {
        if (msg.sender != _entryPoint) revert NotEntryPoint();
        _;
    }

    modifier nonReentrant() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    modifier initializer() {
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;
        _;
    }

    // ============================================================
    //                       CONSTRUCTOR
    // ============================================================

    /// @notice Set immutable EntryPoint and Registry at deploy time
    /// @dev Actual initialization happens in initialize() — allows CREATE2
    constructor(address entryPoint_, address registry_) {
        if (entryPoint_ == address(0) || registry_ == address(0)) revert ZeroAddress();
        _entryPoint = entryPoint_;
        _registry = registry_;
    }

    // ============================================================
    //                      INITIALIZATION
    // ============================================================

    /// @notice Initialize wallet after CREATE2 deployment
    /// @dev Called by AgentWalletFactory immediately after deployment
    function initialize(address owner_, uint256 agentId_) external initializer {
        if (owner_ == address(0)) revert ZeroAddress();
        _owner = owner_;
        _agentId = agentId_;

        emit WalletInitialized(owner_, _entryPoint, agentId_);
    }

    // ============================================================
    //                    RECEIVE ETH
    // ============================================================

    /// @notice Accept ETH — agents earn ETH from completed tasks
    receive() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }

    // ============================================================
    //                    EXECUTION FUNCTIONS
    // ============================================================

    /// @notice Execute a single call on behalf of the agent
    /// @dev Called by EntryPoint (via UserOp) OR directly by owner
    /// @param target Contract or EOA to call
    /// @param value ETH value to send
    /// @param data Calldata to send
    function execute(address target, uint256 value, bytes calldata data)
        external
        override
        onlyOwnerOrEntryPoint
        nonReentrant
    {
        _call(target, value, data);
    }

    /// @notice Execute multiple calls atomically
    /// @dev All calls execute; if any fails, entire batch reverts
    function executeBatch(Call[] calldata calls)
        external
        override
        onlyOwnerOrEntryPoint
        nonReentrant
    {
        uint256 len = calls.length;
        for (uint256 i = 0; i < len; i++) {
            _call(calls[i].target, calls[i].value, calls[i].data);
        }
        emit ExecutedBatch(len, true);
    }

    // ============================================================
    //                  INTERNAL CALL HELPER
    // ============================================================

    function _call(address target, uint256 value, bytes memory data) internal {
        if (value > 0 && address(this).balance < value) {
            revert InsufficientBalance(value, address(this).balance);
        }

        (bool success, bytes memory returnData) = target.call{value: value}(data);
        if (!success) revert CallFailed(target, returnData);

        emit ExecutedCall(target, value, data, success);
    }

    // ============================================================
    //                  ERC-4337 VALIDATION
    // ============================================================

    /// @notice Validate a UserOperation sent through the EntryPoint
    /// @dev EntryPoint calls this before executing the UserOp
    ///      We validate: (1) nonce, (2) ECDSA signature from owner
    ///      Returns 0 = valid, 1 = invalid
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override onlyEntryPoint returns (uint256 validationData) {
        // Validate nonce (prevent replay)
        require(userOp.nonce == _nonce, "AgentWallet: invalid nonce");
        _nonce++;

        // Validate signature — owner must have signed the userOpHash
        bytes32 ethSignedHash = userOpHash.toEthSignedMessageHash();
        address recovered = ethSignedHash.recover(userOp.signature);

        if (recovered != _owner) {
            return SIG_VALIDATION_FAILED;
        }

        // Pay missing funds to EntryPoint (prefund gas)
        if (missingAccountFunds > 0) {
            (bool success,) = payable(_entryPoint).call{value: missingAccountFunds}("");
            // Intentionally ignore failure — EntryPoint handles this
            (success); // silence unused variable warning
        }

        return SIG_VALIDATION_SUCCESS;
    }

    // ============================================================
    //                    WALLET MANAGEMENT
    // ============================================================

    /// @notice Withdraw ETH from the agent wallet
    function withdrawETH(address payable to, uint256 amount)
        external
        override
        onlyOwner
        nonReentrant
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount > address(this).balance) {
            revert InsufficientBalance(amount, address(this).balance);
        }
        (bool success,) = to.call{value: amount}("");
        require(success, "ETH transfer failed");

        emit ETHWithdrawn(to, amount);
    }

    /// @notice Withdraw ERC-20 tokens from the agent wallet
    function withdrawERC20(address token, address to, uint256 amount)
        external
        override
        onlyOwner
        nonReentrant
    {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(to, amount);

        emit ERC20Withdrawn(token, to, amount);
    }

    /// @notice Add or remove a guardian address
    /// @dev Guardians can trigger wallet recovery (Phase 2 feature)
    function setGuardian(address guardian, bool authorized)
        external
        override
        onlyOwner
    {
        if (guardian == address(0)) revert ZeroAddress();
        _guardians[guardian] = authorized;

        emit GuardianSet(guardian, authorized);
    }

    /// @notice Transfer wallet ownership to a new address
    /// @dev Used when agent operator key rotates
    function transferOwnership(address newOwner)
        external
        override
        onlyOwner
    {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = _owner;
        _owner = newOwner;

        emit OwnershipTransferred(old, newOwner);
    }

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    function owner() external view override returns (address) { return _owner; }

    function entryPoint() external view override returns (address) { return _entryPoint; }

    function agentId() external view override returns (uint256) { return _agentId; }

    function nonce() external view override returns (uint256) { return _nonce; }

    function isGuardian(address guardian) external view override returns (bool) {
        return _guardians[guardian];
    }

    function getBalance() external view override returns (uint256) {
        return address(this).balance;
    }

    function registry() external view returns (address) { return _registry; }
}
