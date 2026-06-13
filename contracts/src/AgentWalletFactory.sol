// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentWalletFactory} from "./interfaces/IAgentWalletFactory.sol";
import {IAgentRegistry} from "./interfaces/IAgentRegistry.sol";
import {AgentWallet} from "./AgentWallet.sol";

/// @title AgentWalletFactory
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Deploys AgentWallet instances using CREATE2 for deterministic addresses
///
/// @dev Why CREATE2?
///   - Wallet address is KNOWN before deployment
///   - Users/protocols can send funds to an agent wallet before it's deployed
///   - The agent deploys the wallet on first use (lazy deployment pattern)
///
/// Flow:
///   1. Agent registers in AgentRegistry → gets agentId
///   2. Call computeWalletAddress() to get the future wallet address
///   3. (Optionally) send ETH/tokens to that address now
///   4. Call deployWallet() → CREATE2 deploys + initializes AgentWallet
///   5. AgentRegistry.setAgentWallet() links the wallet to the agent profile
contract AgentWalletFactory is IAgentWalletFactory {
    // ============================================================
    //                         STORAGE
    // ============================================================

    /// @notice The ERC-4337 EntryPoint address (passed to every wallet)
    address public immutable override entryPoint;

    /// @notice The AgentRegistry (validates agent exists before deploying)
    address public immutable override registry;

    /// @notice owner => deployed wallet address (0x0 if not deployed)
    mapping(address => address) private _wallets;

    // ============================================================
    //                       CONSTRUCTOR
    // ============================================================

    constructor(address _entryPoint, address _registry) {
        if (_entryPoint == address(0) || _registry == address(0)) {
            revert ZeroAddress();
        }
        entryPoint = _entryPoint;
        registry = _registry;
    }

    // ============================================================
    //                      DEPLOY WALLET
    // ============================================================

    /// @notice Deploy an AgentWallet for a registered agent via CREATE2
    /// @param owner The agent's controlling EOA
    /// @param agentId The agent's ID from AgentRegistry
    /// @param salt Extra entropy (use 0 for standard deployment)
    /// @return wallet The deployed wallet address
    function deployWallet(
        address owner,
        uint256 agentId,
        bytes32 salt
    ) external override returns (address wallet) {
        if (owner == address(0)) revert ZeroAddress();

        // Prevent double deployment
        if (_wallets[owner] != address(0)) revert WalletAlreadyExists(owner);

        // Verify agent is registered
        require(
            IAgentRegistry(registry).isRegistered(owner),
            "AgentWalletFactory: owner not registered as agent"
        );

        // Compute CREATE2 salt combining owner + agentId + extra salt
        bytes32 create2Salt = _computeSalt(owner, agentId, salt);

        // Deploy via CREATE2
        bytes memory bytecode = _getCreationBytecode();
        address deployed;
        assembly {
            deployed := create2(0, add(bytecode, 0x20), mload(bytecode), create2Salt)
        }

        if (deployed == address(0)) revert DeploymentFailed();

        // Initialize the wallet
        AgentWallet(payable(deployed)).initialize(owner, agentId);

        // Record deployment
        _wallets[owner] = deployed;
        wallet = deployed;

        emit WalletDeployed(deployed, owner, agentId, create2Salt);
    }

    // ============================================================
    //                    COMPUTE ADDRESS
    // ============================================================

    /// @notice Predict the wallet address before deployment
    /// @dev Allows pre-funding — send ETH/tokens here before calling deployWallet
    function computeWalletAddress(
        address owner,
        uint256 agentId,
        bytes32 salt
    ) external view override returns (address) {
        bytes32 create2Salt = _computeSalt(owner, agentId, salt);
        bytes32 bytecodeHash = keccak256(_getCreationBytecode());

        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            create2Salt,
            bytecodeHash
        )))));
    }

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    function hasWallet(address owner) external view override returns (bool) {
        return _wallets[owner] != address(0);
    }

    function getWallet(address owner) external view override returns (address) {
        return _wallets[owner];
    }

    // ============================================================
    //                      INTERNAL HELPERS
    // ============================================================

    /// @notice Compute deterministic CREATE2 salt
    function _computeSalt(
        address owner,
        uint256 agentId,
        bytes32 extraSalt
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, agentId, extraSalt));
    }

    /// @notice Get the creation bytecode for AgentWallet with constructor args
    function _getCreationBytecode() internal view returns (bytes memory) {
        return abi.encodePacked(
            type(AgentWallet).creationCode,
            abi.encode(entryPoint, registry)
        );
    }
}
