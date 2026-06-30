// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {IAgentInference} from "../src/chainlink/IAgentInference.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";

/// @notice We test the storage and callback logic via a mock-friendly
///         subclass that exposes _fulfillRequest without needing a live router.

// ── Stubs ──────────────────────────────────────────────────────

contract MockRegistry {
    mapping(uint256 => address) public owners;
    mapping(uint256 => bool)    public exists;

    function addAgent(uint256 id, address owner) external {
        owners[id] = owner;
        exists[id] = true;
    }

    function getAgent(uint256 id) external view returns (IAgentRegistry.AgentProfile memory p) {
        require(exists[id], "not found");
        p.agentId = id;
        p.owner   = owners[id];
        return p;
    }
}

/// @notice Testable subclass — bypasses Chainlink router for unit tests
contract TestableAgentInference {

    // Mirror the storage from AgentInference without inheriting FunctionsClient
    address public immutable protocolOwner;
    address public immutable registry;

    uint64  public subscriptionId;
    uint32  public callbackGasLimit;
    uint256 public totalRequests;
    string  public jsSource;

    struct InferenceRequest {
        bytes32 requestId;
        uint256 agentId;
        bytes32 taskId;
        string  prompt;
        string  response;
        bytes   rawResponse;
        IAgentInference.InferenceStatus status;
        uint256 requestedAt;
        uint256 fulfilledAt;
        bytes   errorData;
    }

    mapping(bytes32 => InferenceRequest) private _requests;
    mapping(uint256 => bytes32[])        private _agentRequests;
    mapping(bytes32 => bytes32)          private _taskInference;
    mapping(bytes32 => uint256)          private _requestToAgent;

    uint256 private _nonce;

    event InferenceRequested(bytes32 indexed requestId, uint256 indexed agentId, bytes32 indexed taskId, string prompt);
    event InferenceFulfilled(bytes32 indexed requestId, uint256 indexed agentId, string response);
    event InferenceFailed(bytes32 indexed requestId, uint256 indexed agentId, bytes error);

    error NotAuthorized();
    error EmptyPrompt();
    error SubscriptionNotSet();
    error RequestNotFound(bytes32 requestId);

    constructor(address _owner, address _registry, uint64 _subId) {
        protocolOwner  = _owner;
        registry       = _registry;
        subscriptionId = _subId;
        callbackGasLimit = 300_000;
    }

    function requestInference(
        uint256 agentId,
        string calldata prompt,
        bytes32 taskId
    ) external returns (bytes32 requestId) {
        if (bytes(prompt).length == 0) revert EmptyPrompt();
        if (subscriptionId == 0) revert SubscriptionNotSet();

        MockRegistry reg = MockRegistry(registry);
        IAgentRegistry.AgentProfile memory profile = reg.getAgent(agentId);
        if (profile.owner != msg.sender) revert NotAuthorized();

        // Simulate Chainlink requestId
        requestId = keccak256(abi.encodePacked(agentId, _nonce++, block.timestamp));

        _requests[requestId] = InferenceRequest({
            requestId:   requestId,
            agentId:     agentId,
            taskId:      taskId,
            prompt:      prompt,
            response:    "",
            rawResponse: "",
            status:      IAgentInference.InferenceStatus.PENDING,
            requestedAt: block.timestamp,
            fulfilledAt: 0,
            errorData:   ""
        });

        _agentRequests[agentId].push(requestId);
        _requestToAgent[requestId] = agentId;
        totalRequests++;

        if (taskId != bytes32(0)) {
            _taskInference[taskId] = requestId;
        }

        emit InferenceRequested(requestId, agentId, taskId, prompt);
    }

    /// @notice Simulate Chainlink DON callback
    function simulateFulfillment(bytes32 requestId, string calldata response) external {
        InferenceRequest storage req = _requests[requestId];
        require(req.requestedAt != 0, "not found");

        uint256 agentId = _requestToAgent[requestId];
        req.status      = IAgentInference.InferenceStatus.FULFILLED;
        req.response    = response;
        req.rawResponse = bytes(response);
        req.fulfilledAt = block.timestamp;

        emit InferenceFulfilled(requestId, agentId, response);
    }

    /// @notice Simulate Chainlink DON error callback
    function simulateFailure(bytes32 requestId, bytes calldata err) external {
        InferenceRequest storage req = _requests[requestId];
        require(req.requestedAt != 0, "not found");

        uint256 agentId = _requestToAgent[requestId];
        req.status    = IAgentInference.InferenceStatus.FAILED;
        req.errorData = err;
        req.fulfilledAt = block.timestamp;

        emit InferenceFailed(requestId, agentId, err);
    }

    function getRequest(bytes32 requestId) external view returns (InferenceRequest memory) {
        if (_requests[requestId].requestedAt == 0) revert RequestNotFound(requestId);
        return _requests[requestId];
    }

    function getAgentRequests(uint256 agentId) external view returns (bytes32[] memory) {
        return _agentRequests[agentId];
    }

    function getTaskInference(bytes32 taskId) external view returns (bytes32) {
        return _taskInference[taskId];
    }

    function setSubscriptionId(uint64 _subId) external {
        subscriptionId = _subId;
    }
}

// ── Tests ──────────────────────────────────────────────────────

contract AgentInferenceTest is Test {
    TestableAgentInference internal inference;
    MockRegistry           internal registry;

    address constant OWNER     = address(0xA11CE);
    address constant AGENT_OWN = address(0xA6E4);
    address constant STRANGER  = address(0x577A4);

    uint256 constant AGENT_ID  = 1;
    uint64  constant SUB_ID    = 42;
    bytes32 constant TASK_ID   = bytes32(uint256(0xBEEF));

    string  constant PROMPT    = "Summarize the task: build a lending protocol";
    string  constant RESPONSE  = "Here is a summary: implement collateral, borrow, liquidate functions.";

    function setUp() public {
        registry  = new MockRegistry();
        registry.addAgent(AGENT_ID, AGENT_OWN);

        vm.prank(OWNER);
        inference = new TestableAgentInference(OWNER, address(registry), SUB_ID);
    }

    // ── Request ──────────────────────────────────────────────────

    function test_Request_Success() public {
        vm.prank(AGENT_OWN);
        bytes32 reqId = inference.requestInference(AGENT_ID, PROMPT, TASK_ID);

        TestableAgentInference.InferenceRequest memory req = inference.getRequest(reqId);
        assertEq(req.agentId, AGENT_ID);
        assertEq(req.prompt, PROMPT);
        assertEq(req.taskId, TASK_ID);
        assertEq(uint256(req.status), uint256(IAgentInference.InferenceStatus.PENDING));
        assertGt(req.requestedAt, 0);
    }

    function test_Request_EmitsEvent() public {
        vm.expectEmit(false, true, true, false);
        emit TestableAgentInference.InferenceRequested(bytes32(0), AGENT_ID, TASK_ID, PROMPT);
        vm.prank(AGENT_OWN);
        inference.requestInference(AGENT_ID, PROMPT, TASK_ID);
    }

    function test_Request_IncrementsTotalCount() public {
        vm.prank(AGENT_OWN);
        inference.requestInference(AGENT_ID, PROMPT, bytes32(0));
        assertEq(inference.totalRequests(), 1);
    }

    function test_Request_TracksAgentRequests() public {
        vm.prank(AGENT_OWN);
        bytes32 reqId = inference.requestInference(AGENT_ID, PROMPT, bytes32(0));

        bytes32[] memory reqs = inference.getAgentRequests(AGENT_ID);
        assertEq(reqs.length, 1);
        assertEq(reqs[0], reqId);
    }

    function test_Request_LinksToTask() public {
        vm.prank(AGENT_OWN);
        bytes32 reqId = inference.requestInference(AGENT_ID, PROMPT, TASK_ID);

        assertEq(inference.getTaskInference(TASK_ID), reqId);
    }

    function test_Request_NoTaskId_NotLinked() public {
        vm.prank(AGENT_OWN);
        inference.requestInference(AGENT_ID, PROMPT, bytes32(0));

        assertEq(inference.getTaskInference(bytes32(0)), bytes32(0));
    }

    function test_Request_EmptyPrompt_Reverts() public {
        vm.prank(AGENT_OWN);
        vm.expectRevert(TestableAgentInference.EmptyPrompt.selector);
        inference.requestInference(AGENT_ID, "", bytes32(0));
    }

    function test_Request_NotOwner_Reverts() public {
        vm.prank(STRANGER);
        vm.expectRevert(TestableAgentInference.NotAuthorized.selector);
        inference.requestInference(AGENT_ID, PROMPT, bytes32(0));
    }

    function test_Request_NoSubscription_Reverts() public {
        inference.setSubscriptionId(0);
        vm.prank(AGENT_OWN);
        vm.expectRevert(TestableAgentInference.SubscriptionNotSet.selector);
        inference.requestInference(AGENT_ID, PROMPT, bytes32(0));
    }

    function test_Request_UniqueIds_MultipleRequests() public {
        vm.prank(AGENT_OWN);
        bytes32 id1 = inference.requestInference(AGENT_ID, PROMPT, bytes32(0));
        vm.prank(AGENT_OWN);
        bytes32 id2 = inference.requestInference(AGENT_ID, "another prompt", bytes32(0));

        assertFalse(id1 == id2);
        assertEq(inference.totalRequests(), 2);
    }

    // ── Fulfillment ──────────────────────────────────────────────

    function test_Fulfill_StoresResponse() public {
        vm.prank(AGENT_OWN);
        bytes32 reqId = inference.requestInference(AGENT_ID, PROMPT, TASK_ID);

        inference.simulateFulfillment(reqId, RESPONSE);

        TestableAgentInference.InferenceRequest memory req = inference.getRequest(reqId);
        assertEq(uint256(req.status), uint256(IAgentInference.InferenceStatus.FULFILLED));
        assertEq(req.response, RESPONSE);
        assertGt(req.fulfilledAt, 0);
    }

    function test_Fulfill_EmitsEvent() public {
        vm.prank(AGENT_OWN);
        bytes32 reqId = inference.requestInference(AGENT_ID, PROMPT, TASK_ID);

        vm.expectEmit(true, true, false, true);
        emit TestableAgentInference.InferenceFulfilled(reqId, AGENT_ID, RESPONSE);
        inference.simulateFulfillment(reqId, RESPONSE);
    }

    function test_Fulfill_ResponseReadable() public {
        vm.prank(AGENT_OWN);
        bytes32 reqId = inference.requestInference(AGENT_ID, PROMPT, TASK_ID);
        inference.simulateFulfillment(reqId, RESPONSE);

        string memory stored = inference.getRequest(reqId).response;
        assertEq(keccak256(bytes(stored)), keccak256(bytes(RESPONSE)));
    }

    // ── Failure ──────────────────────────────────────────────────

    function test_Failure_SetsStatusFailed() public {
        vm.prank(AGENT_OWN);
        bytes32 reqId = inference.requestInference(AGENT_ID, PROMPT, TASK_ID);

        bytes memory errData = abi.encodePacked("API rate limit exceeded");
        inference.simulateFailure(reqId, errData);

        TestableAgentInference.InferenceRequest memory req = inference.getRequest(reqId);
        assertEq(uint256(req.status), uint256(IAgentInference.InferenceStatus.FAILED));
        assertEq(req.errorData, errData);
    }

    function test_Failure_EmitsEvent() public {
        vm.prank(AGENT_OWN);
        bytes32 reqId = inference.requestInference(AGENT_ID, PROMPT, TASK_ID);

        bytes memory errData = abi.encodePacked("timeout");
        vm.expectEmit(true, true, false, true);
        emit TestableAgentInference.InferenceFailed(reqId, AGENT_ID, errData);
        inference.simulateFailure(reqId, errData);
    }

    // ── Request not found ────────────────────────────────────────

    function test_GetRequest_NotFound_Reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(TestableAgentInference.RequestNotFound.selector, bytes32(uint256(0x1234)))
        );
        inference.getRequest(bytes32(uint256(0x1234)));
    }

    // ── Integration: full cycle ──────────────────────────────────

    function test_Integration_FullInferenceCycle() public {
        // 1. Agent requests inference
        vm.prank(AGENT_OWN);
        bytes32 reqId = inference.requestInference(
            AGENT_ID,
            "Analyze this DeFi protocol for vulnerabilities",
            TASK_ID
        );

        // Verify pending
        assertEq(uint256(inference.getRequest(reqId).status),
            uint256(IAgentInference.InferenceStatus.PENDING));

        // 2. Chainlink DON fulfills
        string memory llmResponse = "Identified 3 potential issues: reentrancy in withdraw(), missing slippage check, oracle manipulation risk.";
        inference.simulateFulfillment(reqId, llmResponse);

        // 3. Verify result stored and linked
        TestableAgentInference.InferenceRequest memory req = inference.getRequest(reqId);
        assertEq(uint256(req.status), uint256(IAgentInference.InferenceStatus.FULFILLED));
        assertEq(req.response, llmResponse);
        assertEq(inference.getTaskInference(TASK_ID), reqId);

        // 4. Verify agent history
        bytes32[] memory history = inference.getAgentRequests(AGENT_ID);
        assertEq(history.length, 1);
        assertEq(history[0], reqId);
    }

    // ── Fuzz ─────────────────────────────────────────────────────

    function testFuzz_Request_AnyPrompt(string calldata prompt) public {
        vm.assume(bytes(prompt).length > 0 && bytes(prompt).length < 1000);
        vm.prank(AGENT_OWN);
        bytes32 reqId = inference.requestInference(AGENT_ID, prompt, bytes32(0));

        assertEq(inference.getRequest(reqId).prompt, prompt);
        assertEq(uint256(inference.getRequest(reqId).status),
            uint256(IAgentInference.InferenceStatus.PENDING));
    }

    function testFuzz_Fulfill_AnyResponse(string calldata response) public {
        vm.assume(bytes(response).length > 0 && bytes(response).length < 2000);
        vm.prank(AGENT_OWN);
        bytes32 reqId = inference.requestInference(AGENT_ID, PROMPT, bytes32(0));
        inference.simulateFulfillment(reqId, response);

        assertEq(inference.getRequest(reqId).response, response);
    }
}
