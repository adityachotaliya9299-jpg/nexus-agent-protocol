// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


/// @notice Minimal interface for EigenLayer's AVSDirectory
/// @dev Full interface: github.com/Layr-Labs/eigenlayer-contracts
interface IAVSDirectory {
    struct SignatureWithSaltAndExpiry {
        bytes signature;
        bytes32 salt;
        uint256 expiry;
    }

    /// @notice Register an operator to this AVS (called by AVS ServiceManager)
    function registerOperatorToAVS(
        address operator,
        SignatureWithSaltAndExpiry memory operatorSignature
    ) external;

    /// @notice Deregister an operator from this AVS
    function deregisterOperatorFromAVS(address operator) external;

    /// @notice Calculate the digest an operator must sign to register with this AVS
    function calculateOperatorAVSRegistrationDigestHash(
        address operator,
        address avs,
        bytes32 salt,
        uint256 expiry
    ) external view returns (bytes32);

    /// @notice Check if an operator is registered with an AVS
    function avsOperatorStatus(
        address avs,
        address operator
    ) external view returns (uint8);
}

/// @notice Minimal interface for EigenLayer's DelegationManager
interface IDelegationManager {
    struct OperatorDetails {
        address earningsReceiver;
        address delegationApprover;
        uint32 stakerOptOutWindowBlocks;
    }

    /// @notice Register as an EigenLayer operator
    function registerAsOperator(
        OperatorDetails calldata registeringOperatorDetails,
        string calldata metadataURI
    ) external;

    /// @notice Check if an address is a registered EigenLayer operator
    function isOperator(address operator) external view returns (bool);
}
