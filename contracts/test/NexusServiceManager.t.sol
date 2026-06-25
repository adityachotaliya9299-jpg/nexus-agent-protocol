// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {NexusServiceManager} from "../src/avs/NexusServiceManager.sol";
import {IAVSDirectory} from "../src/avs/IEigenLayerAVS.sol";

/// @notice Mock AVSDirectory — records calls without real EigenLayer logic
contract MockAVSDirectory {
    mapping(address => mapping(address => uint8)) public avsOperatorStatus;
    address public lastRegisteredOperator;
    address public lastDeregisteredOperator;

    function registerOperatorToAVS(
        address operator,
        IAVSDirectory.SignatureWithSaltAndExpiry memory
    ) external {
        avsOperatorStatus[msg.sender][operator] = 1; // REGISTERED
        lastRegisteredOperator = operator;
    }

    function deregisterOperatorFromAVS(address operator) external {
        avsOperatorStatus[msg.sender][operator] = 0;
        lastDeregisteredOperator = operator;
    }

    function calculateOperatorAVSRegistrationDigestHash(
        address operator,
        address avs,
        bytes32 salt,
        uint256 expiry
    ) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(operator, avs, salt, expiry));
    }
}

/// @notice Mock ZKVerifier — records operator registrations
contract MockZKVerifier {
    mapping(address => bool) public operators;
    uint256 public registerCount;
    uint256 public deregisterCount;

    function registerAVSOperator(address operator, bytes32) external {
        operators[operator] = true;
        registerCount++;
    }

    function deregisterAVSOperator(address operator) external {
        operators[operator] = false;
        deregisterCount++;
    }
}

contract NexusServiceManagerTest is Test {
    NexusServiceManager internal sm;
    MockAVSDirectory internal avsDir;
    MockZKVerifier internal zkVerifier;

    address constant OWNER     = address(0xA11CE);
    address constant OPERATOR1 = address(0x0P1);
    address constant OPERATOR2 = address(0x0P2);
    uint256 constant AGENT_ID  = 42;

    string constant METADATA_URI = "ipfs://QmNexusAVSMetadata";

    IAVSDirectory.SignatureWithSaltAndExpiry internal validSig;

    function setUp() public {
        avsDir    = new MockAVSDirectory();
        zkVerifier = new MockZKVerifier();

        vm.prank(OWNER);
        sm = new NexusServiceManager(
            OWNER,
            address(avsDir),
            address(zkVerifier),
            address(0), // registry not needed for these tests
            METADATA_URI
        );

        validSig = IAVSDirectory.SignatureWithSaltAndExpiry({
            signature: hex"1234",
            salt: bytes32(uint256(1)),
            expiry: block.timestamp + 1 days
        });
    }

    // ── Deployment ──

    function test_Deployment_OwnerSet() public view {
        assertEq(sm.protocolOwner(), OWNER);
    }

    function test_Deployment_AVSDirectorySet() public view {
        assertEq(sm.avsDirectory(), address(avsDir));
    }

    function test_Deployment_MetadataSet() public view {
        assertEq(sm.avsMetadataURI(), METADATA_URI);
    }

    function test_Deployment_ZeroOperators() public view {
        assertEq(sm.getOperatorCount(), 0);
    }

    // ── Metadata ──

    function test_UpdateMetadata() public {
        vm.prank(OWNER);
        sm.updateAVSMetadataURI("ipfs://QmNewMetadata");
        assertEq(sm.avsMetadataURI(), "ipfs://QmNewMetadata");
    }

    function test_UpdateMetadata_OnlyOwner() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(NexusServiceManager.NotOwner.selector);
        sm.updateAVSMetadataURI("ipfs://malicious");
    }

    // ── Operator registration ──

    function test_RegisterOperator_Success() public {
        vm.prank(OWNER);
        sm.registerOperatorToAVS(OPERATOR1, validSig, AGENT_ID);

        assertTrue(sm.isNexusOperator(OPERATOR1));
        assertEq(sm.operatorAgentId(OPERATOR1), AGENT_ID);
        assertEq(sm.getOperatorCount(), 1);
    }

    function test_RegisterOperator_CallsAVSDirectory() public {
        vm.prank(OWNER);
        sm.registerOperatorToAVS(OPERATOR1, validSig, AGENT_ID);

        assertEq(avsDir.lastRegisteredOperator(), OPERATOR1);
        assertEq(avsDir.avsOperatorStatus(address(sm), OPERATOR1), 1);
    }

    function test_RegisterOperator_AlsoRegistersInZKVerifier() public {
        vm.prank(OWNER);
        sm.registerOperatorToAVS(OPERATOR1, validSig, AGENT_ID);

        assertTrue(zkVerifier.operators(OPERATOR1));
        assertEq(zkVerifier.registerCount(), 1);
    }

    function test_RegisterOperator_OnlyOwner() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(NexusServiceManager.NotOwner.selector);
        sm.registerOperatorToAVS(OPERATOR1, validSig, AGENT_ID);
    }

    function test_RegisterOperator_AlreadyRegisteredReverts() public {
        vm.prank(OWNER);
        sm.registerOperatorToAVS(OPERATOR1, validSig, AGENT_ID);

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(NexusServiceManager.AlreadyRegistered.selector, OPERATOR1));
        sm.registerOperatorToAVS(OPERATOR1, validSig, AGENT_ID);
    }

    function test_RegisterOperator_ZeroAddressReverts() public {
        vm.prank(OWNER);
        vm.expectRevert(NexusServiceManager.ZeroAddress.selector);
        sm.registerOperatorToAVS(address(0), validSig, AGENT_ID);
    }

    function test_RegisterMultipleOperators() public {
        vm.prank(OWNER);
        sm.registerOperatorToAVS(OPERATOR1, validSig, 1);

        vm.prank(OWNER);
        sm.registerOperatorToAVS(OPERATOR2, validSig, 2);

        assertEq(sm.getOperatorCount(), 2);
        assertTrue(sm.isNexusOperator(OPERATOR1));
        assertTrue(sm.isNexusOperator(OPERATOR2));
    }

    // ── Deregistration ──

    function test_DeregisterOperator_Success() public {
        vm.prank(OWNER);
        sm.registerOperatorToAVS(OPERATOR1, validSig, AGENT_ID);

        vm.prank(OWNER);
        sm.deregisterOperatorFromAVS(OPERATOR1);

        assertFalse(sm.isNexusOperator(OPERATOR1));
        assertEq(sm.getOperatorCount(), 0);
    }

    function test_DeregisterOperator_CallsAVSDirectory() public {
        vm.prank(OWNER);
        sm.registerOperatorToAVS(OPERATOR1, validSig, AGENT_ID);

        vm.prank(OWNER);
        sm.deregisterOperatorFromAVS(OPERATOR1);

        assertEq(avsDir.lastDeregisteredOperator(), OPERATOR1);
        assertEq(avsDir.avsOperatorStatus(address(sm), OPERATOR1), 0);
    }

    function test_DeregisterOperator_AlsoDeregistersFromZKVerifier() public {
        vm.prank(OWNER);
        sm.registerOperatorToAVS(OPERATOR1, validSig, AGENT_ID);

        vm.prank(OWNER);
        sm.deregisterOperatorFromAVS(OPERATOR1);

        assertFalse(zkVerifier.operators(OPERATOR1));
        assertEq(zkVerifier.deregisterCount(), 1);
    }

    function test_DeregisterOperator_NotRegisteredReverts() public {
        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(NexusServiceManager.NotRegistered.selector, OPERATOR1));
        sm.deregisterOperatorFromAVS(OPERATOR1);
    }

    function test_DeregisterOperator_OnlyOwner() public {
        vm.prank(OWNER);
        sm.registerOperatorToAVS(OPERATOR1, validSig, AGENT_ID);

        vm.prank(address(0xBAD));
        vm.expectRevert(NexusServiceManager.NotOwner.selector);
        sm.deregisterOperatorFromAVS(OPERATOR1);
    }

    // ── Digest helper ──

    function test_GetOperatorRegistrationDigest() public view {
        bytes32 digest = sm.getOperatorRegistrationDigest(
            OPERATOR1,
            bytes32(uint256(1)),
            block.timestamp + 1 days
        );

        // Should match what MockAVSDirectory computes
        bytes32 expected = keccak256(abi.encodePacked(
            OPERATOR1,
            address(sm),
            bytes32(uint256(1)),
            block.timestamp + 1 days
        ));
        assertEq(digest, expected);
    }

    // ── EigenLayer status ──

    function test_IsRegisteredInEigenLayer_AfterRegister() public {
        vm.prank(OWNER);
        sm.registerOperatorToAVS(OPERATOR1, validSig, AGENT_ID);

        assertTrue(sm.isRegisteredInEigenLayer(OPERATOR1));
    }

    function test_IsRegisteredInEigenLayer_BeforeRegister() public view {
        assertFalse(sm.isRegisteredInEigenLayer(OPERATOR1));
    }

    function test_IsRegisteredInEigenLayer_AfterDeregister() public {
        vm.prank(OWNER);
        sm.registerOperatorToAVS(OPERATOR1, validSig, AGENT_ID);

        vm.prank(OWNER);
        sm.deregisterOperatorFromAVS(OPERATOR1);

        assertFalse(sm.isRegisteredInEigenLayer(OPERATOR1));
    }
}
