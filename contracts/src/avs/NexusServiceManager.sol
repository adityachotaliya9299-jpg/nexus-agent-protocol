// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAVSDirectory} from "./IEigenLayerAVS.sol";
import {IZKVerifier} from "../interfaces/IZKVerifier.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";

/// @title NexusServiceManager
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice EigenLayer AVS ServiceManager for Nexus Agent Protocol.
///
/// @dev This is the contract that EigenLayer recognizes as "the Nexus AVS".
///      It holds the AVS identity in EigenLayer's AVSDirectory and manages
///      which operators are part of the Nexus validator set.
///
///      Flow:
///        1. Deploy this contract (points to EigenLayer AVSDirectory on Sepolia)
///        2. Update AVS metadata URI (makes Nexus appear in EigenLayer's AVS list)
///        3. Operators call registerOperatorToAVS() to join Nexus
///        4. NexusServiceManager calls AVSDirectory.registerOperatorToAVS()
///        5. Operators appear as registered Nexus AVS operators on EigenLayer
///        6. ZKVerifier can check isNexusOperator() for quorum decisions
///
///      EigenLayer Sepolia addresses (March 2025 deployment):
///        AVSDirectory:      0x135DDa560e946695d6f155dAcAfc6f1F25C1F5Af  (Sepolia)
///        DelegationManager: 0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37b  (Sepolia)
contract NexusServiceManager {

    // ============================================================
    //                       CONSTANTS
    // ============================================================

  
    /// @notice EigenLayer AVSDirectory on Sepolia (v1.12.1)

    address public constant AVS_DIRECTORY_SEPOLIA = 0xa789c91ECDdae96865913130B786140Ee17aF545;

    // ============================================================
    //                        STORAGE
    // ============================================================

    address public immutable protocolOwner;
    address public immutable avsDirectory;
    address public immutable zkVerifier;
    address public immutable agentRegistry;

    /// @notice URI pointing to Nexus AVS metadata JSON (hosted on IPFS)
    string public avsMetadataURI;

    /// @notice operator address => registered with EigenLayer
    mapping(address => bool) public isNexusOperator;

    /// @notice operator address => their nexus agentId (if they have one)
    mapping(address => uint256) public operatorAgentId;

    /// @notice all registered operator addresses
    address[] private _operators;

    // ============================================================
    //                         EVENTS
    // ============================================================

    event OperatorRegistered(address indexed operator, uint256 agentId);
    event OperatorDeregistered(address indexed operator);
    event AVSMetadataURIUpdated(string metadataURI);

    // ============================================================
    //                         ERRORS
    // ============================================================

    error NotOwner();
    error AlreadyRegistered(address operator);
    error NotRegistered(address operator);
    error ZeroAddress();
    error InvalidSignature();

    // ============================================================
    //                       MODIFIERS
    // ============================================================

    modifier onlyOwner() {
        if (msg.sender != protocolOwner) revert NotOwner();
        _;
    }

    // ============================================================
    //                      CONSTRUCTOR
    // ============================================================

    constructor(
        address _protocolOwner,
        address _avsDirectory,
        address _zkVerifier,
        address _agentRegistry,
        string memory _metadataURI
    ) {
        if (_protocolOwner == address(0) || _avsDirectory == address(0)) revert ZeroAddress();

        protocolOwner  = _protocolOwner;
        avsDirectory   = _avsDirectory;
        zkVerifier     = _zkVerifier;
        agentRegistry  = _agentRegistry;
        avsMetadataURI = _metadataURI;
    }

    // ============================================================
    //                  AVS METADATA (EigenLayer)
    // ============================================================

    /// @notice Update AVS metadata URI — makes Nexus appear in EigenLayer directory
    /// @dev URI should point to a JSON file with: name, website, description, logo, twitter
    function updateAVSMetadataURI(string calldata _metadataURI) external onlyOwner {
        avsMetadataURI = _metadataURI;
        emit AVSMetadataURIUpdated(_metadataURI);
    }

    // ============================================================
    //                  OPERATOR REGISTRATION
    // ============================================================

    /// @notice Register an EigenLayer operator as a Nexus AVS operator
    /// @dev The operator must already be registered in EigenLayer's DelegationManager.
    ///      They sign an EIP-712 message over (operator, avs=this, salt, expiry)
    ///      using calculateOperatorAVSRegistrationDigestHash from AVSDirectory.
    /// @param operator The operator's address
    /// @param operatorSignature The EIP-712 signature from the operator
    /// @param agentId Optional: the operator's Nexus agentId (0 if they don't have one)
    function registerOperatorToAVS(
        address operator,
        IAVSDirectory.SignatureWithSaltAndExpiry calldata operatorSignature,
        uint256 agentId
    ) external onlyOwner {
        if (operator == address(0)) revert ZeroAddress();
        if (isNexusOperator[operator]) revert AlreadyRegistered(operator);

        // Register with EigenLayer — this is the on-chain registration
        // that makes us a real EigenLayer AVS
        IAVSDirectory(avsDirectory).registerOperatorToAVS(operator, operatorSignature);

        // Track locally
        isNexusOperator[operator] = true;
        operatorAgentId[operator] = agentId;
        _operators.push(operator);

        // Also register in ZKVerifier's operator set if zkVerifier is set
        if (zkVerifier != address(0)) {
            bytes32 operatorId = keccak256(abi.encodePacked(operator, agentId));
            try IZKVerifier(zkVerifier).registerAVSOperator(operator, operatorId) {} catch {}
        }

        emit OperatorRegistered(operator, agentId);
    }

    /// @notice Deregister an operator from Nexus AVS
    function deregisterOperatorFromAVS(address operator) external onlyOwner {
        if (!isNexusOperator[operator]) revert NotRegistered(operator);

        // Deregister from EigenLayer
        IAVSDirectory(avsDirectory).deregisterOperatorFromAVS(operator);

        // Track locally
        isNexusOperator[operator] = false;

        // Remove from list
        for (uint256 i = 0; i < _operators.length; i++) {
            if (_operators[i] == operator) {
                _operators[i] = _operators[_operators.length - 1];
                _operators.pop();
                break;
            }
        }

        // Also deregister from ZKVerifier
        if (zkVerifier != address(0)) {
            try IZKVerifier(zkVerifier).deregisterAVSOperator(operator) {} catch {}
        }

        emit OperatorDeregistered(operator);
    }

    // ============================================================
    //                      VIEW FUNCTIONS
    // ============================================================

    function getOperators() external view returns (address[] memory) {
        return _operators;
    }

    function getOperatorCount() external view returns (uint256) {
        return _operators.length;
    }

    /// @notice Get the digest an operator must sign to register
    /// @dev Operators call this off-chain, sign the result, then send to registerOperatorToAVS
    function getOperatorRegistrationDigest(
        address operator,
        bytes32 salt,
        uint256 expiry
    ) external view returns (bytes32) {
        return IAVSDirectory(avsDirectory).calculateOperatorAVSRegistrationDigestHash(
            operator,
            address(this), // avs = this contract
            salt,
            expiry
        );
    }

    /// @notice Check if an operator is registered in EigenLayer for this AVS
    function isRegisteredInEigenLayer(address operator) external view returns (bool) {
        // 1 = REGISTERED in EigenLayer's OperatorAVSRegistrationStatus enum
        return IAVSDirectory(avsDirectory).avsOperatorStatus(address(this), operator) == 1;
    }
}
