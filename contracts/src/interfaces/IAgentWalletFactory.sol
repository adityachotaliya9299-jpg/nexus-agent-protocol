// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAgentWalletFactory
/// @notice Interface for the factory that deploys AgentWallet instances
/// @dev Uses CREATE2 so wallet addresses are deterministic and predictable
///      before deployment — important for pre-funding agent wallets
interface IAgentWalletFactory {
    // ============================================================
    //                         EVENTS
    // ============================================================

    event WalletDeployed(
        address indexed wallet,
        address indexed owner,
        uint256 indexed agentId,
        bytes32 salt
    );

    // ============================================================
    //                         ERRORS
    // ============================================================

    error WalletAlreadyExists(address owner);
    error DeploymentFailed();
    error ZeroAddress();

    // ============================================================
    //                       CORE FUNCTIONS
    // ============================================================

    /// @notice Deploy a new AgentWallet for a registered agent
    /// @param owner The EOA that will control this wallet
    /// @param agentId The on-chain agent ID from AgentRegistry
    /// @param salt Additional entropy for CREATE2 (use 0 for default)
    /// @return wallet The deployed wallet address
    function deployWallet(
        address owner,
        uint256 agentId,
        bytes32 salt
    ) external returns (address wallet);

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    /// @notice Compute the deterministic wallet address WITHOUT deploying
    /// @dev Used to pre-fund a wallet before it's deployed
    function computeWalletAddress(
        address owner,
        uint256 agentId,
        bytes32 salt
    ) external view returns (address);

    /// @notice Check if a wallet has been deployed for this owner
    function hasWallet(address owner) external view returns (bool);

    /// @notice Get deployed wallet address for an owner (0x0 if not deployed)
    function getWallet(address owner) external view returns (address);

    function entryPoint() external view returns (address);

    function registry() external view returns (address);
}
