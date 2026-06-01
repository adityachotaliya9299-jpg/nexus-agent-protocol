// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AgentWallet} from "../src/AgentWallet.sol";
import {AgentWalletFactory} from "../src/AgentWalletFactory.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {IAgentWallet} from "../src/interfaces/IAgentWallet.sol";
import {IAgentWalletFactory} from "../src/interfaces/IAgentWalletFactory.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// ============================================================
//                     MOCK CONTRACTS
// ============================================================

/// @notice Mock ERC-20 token for payment tests
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Mock EntryPoint — simulates ERC-4337 EntryPoint behavior
contract MockEntryPoint {
    function simulateValidation(
        AgentWallet wallet,
        IAgentWallet.UserOperation calldata userOp,
        bytes32 userOpHash
    ) external returns (uint256) {
        return wallet.validateUserOp(userOp, userOpHash, 0);
    }

    function callExecute(
        AgentWallet wallet,
        address target,
        uint256 value,
        bytes calldata data
    ) external {
        wallet.execute(target, value, data);
    }
}

/// @notice Simple contract to receive calls during execute() tests
contract MockTarget {
    uint256 public value;
    uint256 public ethReceived;
    bool public shouldRevert;

    event Called(address caller, uint256 val, bytes data);

    function setValue(uint256 v) external {
        value = v;
        emit Called(msg.sender, v, "");
    }

    function setRevert(bool v) external {
        shouldRevert = v;
    }

    function failingCall() external pure {
        revert("MockTarget: forced revert");
    }

    receive() external payable {
        ethReceived += msg.value;
        if (shouldRevert) revert("MockTarget: revert on receive");
    }
}

// ============================================================
//                     TEST CONTRACT
// ============================================================

contract AgentWalletTest is Test {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // ============================================================
    //                         SETUP
    // ============================================================

    AgentRegistry public registry;
    AgentWalletFactory public factory;
    MockEntryPoint public entryPoint;
    MockERC20 public token;
    MockTarget public target;

    address public protocolOwner = makeAddr("protocolOwner");

    // Agent operators with known private keys for signature tests
    uint256 public alicePk = 0xA11CE;
    uint256 public bobPk = 0xB0B;
    address public alice;
    address public bob;
    address public charlie = makeAddr("charlie");

    string constant META_URI = "ipfs://QmTestAgentMetadata";

    function setUp() public {
        alice = vm.addr(alicePk);
        bob = vm.addr(bobPk);

        // Deploy core contracts
        entryPoint = new MockEntryPoint();
        registry = new AgentRegistry(protocolOwner);
        factory = new AgentWalletFactory(address(entryPoint), address(registry));
        token = new MockERC20();
        target = new MockTarget();

        // Register alice and bob as agents
        vm.prank(alice);
        registry.registerAgent(META_URI, IAgentRegistry.AgentCategory.CODE);

        vm.prank(bob);
        registry.registerAgent(META_URI, IAgentRegistry.AgentCategory.TRADING);
    }

    // ============================================================
    //           FACTORY: DEPLOYMENT TESTS (6 tests)
    // ============================================================

    function test_Factory_DeployWallet_Success() public {
        vm.prank(alice);
        address wallet = factory.deployWallet(alice, 1, bytes32(0));

        assertTrue(wallet != address(0), "Wallet should be deployed");
        assertTrue(factory.hasWallet(alice), "Factory should track wallet");
        assertEq(factory.getWallet(alice), wallet, "Factory should return correct wallet");
    }

    function test_Factory_DeployWallet_EmitsEvent() public {
        bytes32 expectedSalt = keccak256(abi.encodePacked(alice, uint256(1), bytes32(0)));
        address expectedAddr = factory.computeWalletAddress(alice, 1, bytes32(0));

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit IAgentWalletFactory.WalletDeployed(expectedAddr, alice, 1, expectedSalt);
        factory.deployWallet(alice, 1, bytes32(0));
    }

    function test_Factory_DeployWallet_Revert_NotRegistered() public {
        vm.prank(charlie); // charlie is not registered in AgentRegistry
        vm.expectRevert("AgentWalletFactory: owner not registered as agent");
        factory.deployWallet(charlie, 99, bytes32(0));
    }

    function test_Factory_DeployWallet_Revert_AlreadyDeployed() public {
        vm.prank(alice);
        factory.deployWallet(alice, 1, bytes32(0));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAgentWalletFactory.WalletAlreadyExists.selector, alice));
        factory.deployWallet(alice, 1, bytes32(0));
    }

    function test_Factory_DeployWallet_Revert_ZeroAddress() public {
        vm.expectRevert(IAgentWalletFactory.ZeroAddress.selector);
        factory.deployWallet(address(0), 1, bytes32(0));
    }

    function test_Factory_ComputeAddress_MatchesDeployed() public {
        address predicted = factory.computeWalletAddress(alice, 1, bytes32(0));

        vm.prank(alice);
        address actual = factory.deployWallet(alice, 1, bytes32(0));

        assertEq(predicted, actual, "Predicted address must match deployed address");
    }

    function test_Factory_ComputeAddress_DifferentSalts() public {
        address addr1 = factory.computeWalletAddress(alice, 1, bytes32(0));
        address addr2 = factory.computeWalletAddress(alice, 1, bytes32(uint256(1)));

        assertTrue(addr1 != addr2, "Different salts must produce different addresses");
    }

    function test_Factory_HasWallet_BeforeAndAfter() public {
        assertFalse(factory.hasWallet(alice), "Should not have wallet before deploy");

        vm.prank(alice);
        factory.deployWallet(alice, 1, bytes32(0));

        assertTrue(factory.hasWallet(alice), "Should have wallet after deploy");
    }

    // ============================================================
    //         WALLET INITIALIZATION TESTS (4 tests)
    // ============================================================

    function test_Wallet_Initialized_CorrectState() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        AgentWallet wallet = AgentWallet(payable(walletAddr));

        assertEq(wallet.owner(), alice, "Owner should be alice");
        assertEq(wallet.entryPoint(), address(entryPoint), "EntryPoint should be set");
        assertEq(wallet.agentId(), 1, "AgentId should be 1");
        assertEq(wallet.nonce(), 0, "Initial nonce should be 0");
        assertEq(wallet.registry(), address(registry), "Registry should be set");
    }

    function test_Wallet_Initialized_EmitsEvent() public {
        address predicted = factory.computeWalletAddress(alice, 1, bytes32(0));

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit IAgentWallet.WalletInitialized(alice, address(entryPoint), 1);
        factory.deployWallet(alice, 1, bytes32(0));
    }

    function test_Wallet_Initialize_Revert_AlreadyInitialized() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        AgentWallet wallet = AgentWallet(payable(walletAddr));

        // Try to re-initialize directly
        vm.expectRevert(IAgentWallet.AlreadyInitialized.selector);
        wallet.initialize(bob, 2);
    }

    function test_Wallet_Initialize_Revert_ZeroOwner() public {
        // Deploy wallet directly (bypassing factory) to test zero owner
        AgentWallet wallet = new AgentWallet(address(entryPoint), address(registry));
        vm.expectRevert(IAgentWallet.ZeroAddress.selector);
        wallet.initialize(address(0), 1);
    }

    // ============================================================
    //           WALLET: RECEIVE ETH TESTS (2 tests)
    // ============================================================

    function test_Wallet_ReceiveETH() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        AgentWallet wallet = AgentWallet(payable(walletAddr));

        vm.deal(address(this), 1 ether);
        (bool success,) = payable(walletAddr).call{value: 1 ether}("");

        assertTrue(success);
        assertEq(wallet.getBalance(), 1 ether);
    }

    function test_Wallet_ReceiveETH_EmitsEvent() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));

        vm.deal(address(this), 0.5 ether);
        vm.expectEmit(true, true, false, true);
        emit IAgentWallet.ETHReceived(address(this), 0.5 ether);
        (bool success,) = payable(walletAddr).call{value: 0.5 ether}("");
        assertTrue(success);
    }

    // ============================================================
    //           WALLET: EXECUTE TESTS (7 tests)
    // ============================================================

    function test_Execute_ByOwner_Success() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        AgentWallet wallet = AgentWallet(payable(walletAddr));

        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, uint256(42));

        vm.prank(alice);
        wallet.execute(address(target), 0, data);

        assertEq(target.value(), 42, "Target value should be 42");
    }

    function test_Execute_ByEntryPoint_Success() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));

        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, uint256(99));

        // EntryPoint calling execute
        vm.prank(address(entryPoint));
        AgentWallet(payable(walletAddr)).execute(address(target), 0, data);

        assertEq(target.value(), 99);
    }

    function test_Execute_WithETH_Transfer() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));

        // Fund the wallet
        vm.deal(walletAddr, 2 ether);

        vm.prank(alice);
        AgentWallet(payable(walletAddr)).execute(address(target), 1 ether, "");

        assertEq(target.ethReceived(), 1 ether, "Target should receive 1 ETH");
        assertEq(address(walletAddr).balance, 1 ether, "Wallet should have 1 ETH left");
    }

    function test_Execute_Revert_NotOwnerOrEntryPoint() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));

        vm.prank(charlie); // charlie is unauthorized
        vm.expectRevert(IAgentWallet.NotOwnerOrEntryPoint.selector);
        AgentWallet(payable(walletAddr)).execute(address(target), 0, "");
    }

    function test_Execute_Revert_CallFailed() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));

        bytes memory data = abi.encodeWithSelector(MockTarget.failingCall.selector);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAgentWallet.CallFailed.selector, address(target), abi.encodeWithSignature("Error(string)", "MockTarget: forced revert"))
        );
        AgentWallet(payable(walletAddr)).execute(address(target), 0, data);
    }

    function test_Execute_Revert_InsufficientBalance() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        // Wallet has 0 balance

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAgentWallet.InsufficientBalance.selector, 1 ether, 0)
        );
        AgentWallet(payable(walletAddr)).execute(address(target), 1 ether, "");
    }

    function test_Execute_EmitsEvent() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));

        bytes memory data = abi.encodeWithSelector(MockTarget.setValue.selector, uint256(7));

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit IAgentWallet.ExecutedCall(address(target), 0, data, true);
        AgentWallet(payable(walletAddr)).execute(address(target), 0, data);
    }

    // ============================================================
    //         WALLET: EXECUTE BATCH TESTS (4 tests)
    // ============================================================

    function test_ExecuteBatch_MultipleCallsSuccess() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        AgentWallet wallet = AgentWallet(payable(walletAddr));

        IAgentWallet.Call[] memory calls = new IAgentWallet.Call[](2);
        calls[0] = IAgentWallet.Call({
            target: address(target),
            value: 0,
            data: abi.encodeWithSelector(MockTarget.setValue.selector, uint256(100))
        });
        calls[1] = IAgentWallet.Call({
            target: address(target),
            value: 0,
            data: abi.encodeWithSelector(MockTarget.setValue.selector, uint256(200))
        });

        vm.prank(alice);
        wallet.executeBatch(calls);

        assertEq(target.value(), 200, "Last call value should be 200");
    }

    function test_ExecuteBatch_Revert_NotOwner() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));

        IAgentWallet.Call[] memory calls = new IAgentWallet.Call[](1);
        calls[0] = IAgentWallet.Call({target: address(target), value: 0, data: ""});

        vm.prank(charlie);
        vm.expectRevert(IAgentWallet.NotOwnerOrEntryPoint.selector);
        AgentWallet(payable(walletAddr)).executeBatch(calls);
    }

    function test_ExecuteBatch_Revert_IfOneCallFails() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));

        IAgentWallet.Call[] memory calls = new IAgentWallet.Call[](2);
        calls[0] = IAgentWallet.Call({
            target: address(target),
            value: 0,
            data: abi.encodeWithSelector(MockTarget.setValue.selector, uint256(1))
        });
        calls[1] = IAgentWallet.Call({
            target: address(target),
            value: 0,
            data: abi.encodeWithSelector(MockTarget.failingCall.selector)
        });

        vm.prank(alice);
        vm.expectRevert(); // Should revert because 2nd call fails
        AgentWallet(payable(walletAddr)).executeBatch(calls);
    }

    function test_ExecuteBatch_EmptyBatch() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));

        IAgentWallet.Call[] memory calls = new IAgentWallet.Call[](0);

        vm.prank(alice);
        AgentWallet(payable(walletAddr)).executeBatch(calls); // Should not revert
    }

    // ============================================================
    //           WALLET: WITHDRAWAL TESTS (5 tests)
    // ============================================================

    function test_WithdrawETH_Success() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        vm.deal(walletAddr, 2 ether);

        uint256 aliceBalanceBefore = alice.balance;

        vm.prank(alice);
        AgentWallet(payable(walletAddr)).withdrawETH(payable(alice), 1 ether);

        assertEq(alice.balance, aliceBalanceBefore + 1 ether);
        assertEq(address(walletAddr).balance, 1 ether);
    }

    function test_WithdrawETH_Revert_NotOwner() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        vm.deal(walletAddr, 1 ether);

        vm.prank(charlie);
        vm.expectRevert(IAgentWallet.NotOwnerOrEntryPoint.selector);
        AgentWallet(payable(walletAddr)).withdrawETH(payable(charlie), 0.5 ether);
    }

    function test_WithdrawETH_Revert_InsufficientBalance() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        // Wallet has 0 ETH

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAgentWallet.InsufficientBalance.selector, 1 ether, 0)
        );
        AgentWallet(payable(walletAddr)).withdrawETH(payable(alice), 1 ether);
    }

    function test_WithdrawERC20_Success() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));

        // Send tokens to wallet
        token.mint(walletAddr, 1000e18);

        vm.prank(alice);
        AgentWallet(payable(walletAddr)).withdrawERC20(address(token), alice, 500e18);

        assertEq(token.balanceOf(alice), 500e18);
        assertEq(token.balanceOf(walletAddr), 500e18);
    }

    function test_WithdrawERC20_Revert_NotOwner() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        token.mint(walletAddr, 1000e18);

        vm.prank(charlie);
        vm.expectRevert(IAgentWallet.NotOwnerOrEntryPoint.selector);
        AgentWallet(payable(walletAddr)).withdrawERC20(address(token), charlie, 100e18);
    }

    // ============================================================
    //           WALLET: GUARDIAN TESTS (3 tests)
    // ============================================================

    function test_SetGuardian_Success() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        AgentWallet wallet = AgentWallet(payable(walletAddr));

        assertFalse(wallet.isGuardian(charlie));

        vm.prank(alice);
        wallet.setGuardian(charlie, true);

        assertTrue(wallet.isGuardian(charlie));
    }

    function test_SetGuardian_Remove() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        AgentWallet wallet = AgentWallet(payable(walletAddr));

        vm.prank(alice);
        wallet.setGuardian(charlie, true);
        assertTrue(wallet.isGuardian(charlie));

        vm.prank(alice);
        wallet.setGuardian(charlie, false);
        assertFalse(wallet.isGuardian(charlie));
    }

    function test_SetGuardian_Revert_NotOwner() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));

        vm.prank(charlie);
        vm.expectRevert(IAgentWallet.NotOwnerOrEntryPoint.selector);
        AgentWallet(payable(walletAddr)).setGuardian(bob, true);
    }

    // ============================================================
    //         WALLET: OWNERSHIP TRANSFER TESTS (3 tests)
    // ============================================================

    function test_TransferOwnership_Success() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        AgentWallet wallet = AgentWallet(payable(walletAddr));

        vm.prank(alice);
        wallet.transferOwnership(bob);

        assertEq(wallet.owner(), bob, "Owner should now be bob");
    }

    function test_TransferOwnership_Revert_NotOwner() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));

        vm.prank(charlie);
        vm.expectRevert(IAgentWallet.NotOwnerOrEntryPoint.selector);
        AgentWallet(payable(walletAddr)).transferOwnership(charlie);
    }

    function test_TransferOwnership_Revert_ZeroAddress() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));

        vm.prank(alice);
        vm.expectRevert(IAgentWallet.ZeroAddress.selector);
        AgentWallet(payable(walletAddr)).transferOwnership(address(0));
    }

    // ============================================================
    //       WALLET: ERC-4337 USEROP VALIDATION TESTS (4 tests)
    // ============================================================

    function _buildUserOp(address sender, uint256 nonce_) internal pure returns (IAgentWallet.UserOperation memory) {
        return IAgentWallet.UserOperation({
            sender: sender,
            nonce: nonce_,
            initCode: "",
            callData: "",
            callGasLimit: 100000,
            verificationGasLimit: 100000,
            preVerificationGas: 21000,
            maxFeePerGas: 1 gwei,
            maxPriorityFeePerGas: 1 gwei,
            paymasterAndData: "",
            signature: ""
        });
    }

    function _signUserOp(
        IAgentWallet.UserOperation memory userOp,
        bytes32 userOpHash,
        uint256 privateKey
    ) internal pure returns (IAgentWallet.UserOperation memory) {
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethHash);
        userOp.signature = abi.encodePacked(r, s, v);
        return userOp;
    }

    function test_ValidateUserOp_ValidSignature_Returns0() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        AgentWallet wallet = AgentWallet(payable(walletAddr));

        bytes32 userOpHash = keccak256("test-userop-hash");
        IAgentWallet.UserOperation memory userOp = _buildUserOp(walletAddr, 0);
        userOp = _signUserOp(userOp, userOpHash, alicePk);

        vm.prank(address(entryPoint));
        uint256 result = wallet.validateUserOp(userOp, userOpHash, 0);

        assertEq(result, 0, "Valid signature should return 0");
    }

    function test_ValidateUserOp_InvalidSignature_Returns1() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        AgentWallet wallet = AgentWallet(payable(walletAddr));

        bytes32 userOpHash = keccak256("test-userop-hash");
        IAgentWallet.UserOperation memory userOp = _buildUserOp(walletAddr, 0);
        // Sign with bob's key instead of alice's
        userOp = _signUserOp(userOp, userOpHash, bobPk);

        vm.prank(address(entryPoint));
        uint256 result = wallet.validateUserOp(userOp, userOpHash, 0);

        assertEq(result, 1, "Wrong signer should return 1 (failure)");
    }

    function test_ValidateUserOp_IncrementsNonce() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        AgentWallet wallet = AgentWallet(payable(walletAddr));

        assertEq(wallet.nonce(), 0);

        bytes32 userOpHash = keccak256("test");
        IAgentWallet.UserOperation memory userOp = _buildUserOp(walletAddr, 0);
        userOp = _signUserOp(userOp, userOpHash, alicePk);

        vm.prank(address(entryPoint));
        wallet.validateUserOp(userOp, userOpHash, 0);

        assertEq(wallet.nonce(), 1, "Nonce should increment after validation");
    }

    function test_ValidateUserOp_Revert_WrongNonce() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        AgentWallet wallet = AgentWallet(payable(walletAddr));

        bytes32 userOpHash = keccak256("test");
        IAgentWallet.UserOperation memory userOp = _buildUserOp(walletAddr, 999); // wrong nonce
        userOp = _signUserOp(userOp, userOpHash, alicePk);

        vm.prank(address(entryPoint));
        vm.expectRevert("AgentWallet: invalid nonce");
        wallet.validateUserOp(userOp, userOpHash, 0);
    }

    function test_ValidateUserOp_Revert_NotEntryPoint() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        AgentWallet wallet = AgentWallet(payable(walletAddr));

        bytes32 userOpHash = keccak256("test");
        IAgentWallet.UserOperation memory userOp = _buildUserOp(walletAddr, 0);

        vm.prank(alice); // alice calling validateUserOp directly (not EntryPoint)
        vm.expectRevert(IAgentWallet.NotEntryPoint.selector);
        wallet.validateUserOp(userOp, userOpHash, 0);
    }

    // ============================================================
    //           INTEGRATION TESTS (4 tests)
    // ============================================================

    function test_Integration_AgentWallet_LinkedToRegistry() public {
        // Deploy wallet
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));

        // Link wallet to registry
        vm.prank(alice);
        registry.setAgentWallet(1, walletAddr);

        // Verify the link
        IAgentRegistry.AgentProfile memory profile = registry.getAgent(1);
        assertEq(profile.agentWallet, walletAddr, "Registry should link to wallet");
    }

    function test_Integration_TwoAgents_SeparateWallets() public {
        vm.prank(alice);
        address aliceWallet = factory.deployWallet(alice, 1, bytes32(0));

        vm.prank(bob);
        address bobWallet = factory.deployWallet(bob, 2, bytes32(0));

        assertTrue(aliceWallet != bobWallet, "Each agent should have unique wallet");
        assertEq(AgentWallet(payable(aliceWallet)).owner(), alice);
        assertEq(AgentWallet(payable(bobWallet)).owner(), bob);
    }

    function test_Integration_WalletReceivesPayment_ThenWithdraws() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));

        // Simulate task payment arriving at wallet
        vm.deal(address(this), 5 ether);
        (bool sent,) = payable(walletAddr).call{value: 5 ether}("");
        assertTrue(sent);
        assertEq(AgentWallet(payable(walletAddr)).getBalance(), 5 ether);

        // Alice withdraws earnings
        uint256 before = alice.balance;
        vm.prank(alice);
        AgentWallet(payable(walletAddr)).withdrawETH(payable(alice), 5 ether);
        assertEq(alice.balance, before + 5 ether);
    }

    function test_Integration_WalletExecutesThenReceivesERC20() public {
        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));

        // Mint tokens directly to wallet (task payment)
        token.mint(walletAddr, 100e18);
        assertEq(token.balanceOf(walletAddr), 100e18);

        // Alice withdraws ERC-20 earnings
        vm.prank(alice);
        AgentWallet(payable(walletAddr)).withdrawERC20(address(token), alice, 100e18);
        assertEq(token.balanceOf(alice), 100e18);
        assertEq(token.balanceOf(walletAddr), 0);
    }

    // ============================================================
    //                    FUZZ TESTS (3 tests)
    // ============================================================

    function testFuzz_WithdrawETH_ValidAmount(uint256 depositAmount, uint256 withdrawAmount) public {
        vm.assume(depositAmount > 0 && depositAmount <= 100 ether);
        vm.assume(withdrawAmount > 0 && withdrawAmount <= depositAmount);

        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        vm.deal(walletAddr, depositAmount);

        uint256 before = alice.balance;
        vm.prank(alice);
        AgentWallet(payable(walletAddr)).withdrawETH(payable(alice), withdrawAmount);

        assertEq(alice.balance, before + withdrawAmount);
        assertEq(address(walletAddr).balance, depositAmount - withdrawAmount);
    }

    function testFuzz_Factory_ComputeAddress_Deterministic(bytes32 salt) public view {
        address addr1 = factory.computeWalletAddress(alice, 1, salt);
        address addr2 = factory.computeWalletAddress(alice, 1, salt);
        assertEq(addr1, addr2, "Same inputs must always produce same address");
    }

    function testFuzz_SetGuardian_MultipleGuardians(address guardian1, address guardian2) public {
        vm.assume(guardian1 != address(0));
        vm.assume(guardian2 != address(0));
        vm.assume(guardian1 != guardian2);

        vm.prank(alice);
        address walletAddr = factory.deployWallet(alice, 1, bytes32(0));
        AgentWallet wallet = AgentWallet(payable(walletAddr));

        vm.startPrank(alice);
        wallet.setGuardian(guardian1, true);
        wallet.setGuardian(guardian2, true);
        vm.stopPrank();

        assertTrue(wallet.isGuardian(guardian1));
        assertTrue(wallet.isGuardian(guardian2));
    }
}
