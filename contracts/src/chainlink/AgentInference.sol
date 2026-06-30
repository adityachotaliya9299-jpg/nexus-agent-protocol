// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentInference} from "./IAgentInference.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

/// @title AgentInference
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Chainlink Functions consumer — agents trigger real LLM inference on-chain.
///
/// @dev This contract inherits from Chainlink's FunctionsClient.
///      When an agent calls requestInference(), this contract:
///        1. Encodes the prompt and DON JS source into a Chainlink request
///        2. Sends it to the Chainlink Functions Router on Sepolia
///        3. The DON picks it up, runs the JS, calls the LLM API
///        4. The DON calls back fulfillRequest() with the response
///        5. We store response, emit event, link to task
///
///      The JS source is stored in jsSource (settable by owner).
///      It should call an LLM API and return the response as a string.
///
///      Chainlink Functions Sepolia:
///        Router:  0xb83E47C2bC239B3bf370bc41e1459A34b41238D0
///        DON ID:  0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000
///                 (bytes32 encoding of "fun-ethereum-sepolia-1")
///
///      Setup required:
///        1. Create subscription at functions.chain.link
///        2. Add LINK to subscription
///        3. Add this contract as a consumer
///        4. Call setSubscriptionId() and setJsSource()
contract AgentInference is IAgentInference, FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;

    // ============================================================
    //                       CONSTANTS
    // ============================================================

    /// @notice Chainlink Functions Router on Sepolia
    address public constant FUNCTIONS_ROUTER_SEPOLIA = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;

    /// @notice DON ID for Sepolia ("fun-ethereum-sepolia-1" as bytes32)
    bytes32 public constant DON_ID =
        0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;

    // ============================================================
    //                         STORAGE
    // ============================================================

    address public immutable protocolOwner;
    address public immutable registry;

    uint64  public override subscriptionId;
    uint32  public override callbackGasLimit;
    uint256 public override totalRequests;

    /// @notice JavaScript source executed by the Chainlink DON
    string public jsSource;

    /// @notice Encrypted secrets reference (uploaded to DON via CLI)
    bytes public encryptedSecretsRef;

    /// @notice requestId => InferenceRequest
    mapping(bytes32 => InferenceRequest) private _requests;

    /// @notice agentId => list of requestIds
    mapping(uint256 => bytes32[]) private _agentRequests;

    /// @notice taskId => requestId (latest inference for a task)
    mapping(bytes32 => bytes32) private _taskInference;

    /// @notice Chainlink requestId => our internal agentId (for callback)
    mapping(bytes32 => uint256) private _requestToAgent;

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
        address _registry,
        uint64  _subscriptionId
    ) FunctionsClient(FUNCTIONS_ROUTER_SEPOLIA) {
        if (_protocolOwner == address(0) || _registry == address(0)) revert ZeroAddress();

        protocolOwner    = _protocolOwner;
        registry         = _registry;
        subscriptionId   = _subscriptionId;
        callbackGasLimit = 300_000; // default: enough for string storage + emit

        // Default JS source — calls a simple echo API for testing.
        // Owner should replace with real LLM call via setJsSource().
        jsSource = string(abi.encodePacked(
            "const prompt = args[0];",
            "const res = await Functions.makeHttpRequest({",
            "  url: 'https://api.openai.com/v1/chat/completions',",
            "  method: 'POST',",
            "  headers: {",
            "    'Content-Type': 'application/json',",
            "    'Authorization': `Bearer ${secrets.apiKey}`",
            "  },",
            "  data: {",
            "    model: 'gpt-4o-mini',",
            "    messages: [{ role: 'user', content: prompt }],",
            "    max_tokens: 256",
            "  }",
            "});",
            "if (res.error) throw Error(res.error);",
            "return Functions.encodeString(res.data.choices[0].message.content);"
        ));
    }

    // ============================================================
    //                    REQUEST INFERENCE
    // ============================================================

    /// @notice Agent owner triggers an AI inference request
    /// @param agentId The requesting agent's ID
    /// @param prompt The text prompt to send to the LLM
    /// @param taskId Optional: link this inference to a marketplace task
    function requestInference(
        uint256 agentId,
        string calldata prompt,
        bytes32 taskId
    ) external override returns (bytes32 requestId) {
        if (bytes(prompt).length == 0) revert EmptyPrompt();
        if (subscriptionId == 0) revert SubscriptionNotSet();

        // Verify caller owns the agent
        IAgentRegistry.AgentProfile memory profile = IAgentRegistry(registry).getAgent(agentId);
        if (profile.owner != msg.sender) revert NotAuthorized();

        // Build Chainlink Functions request
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(jsSource);

        // Pass prompt as args[0]
        string[] memory args = new string[](1);
        args[0] = prompt;
        req.setArgs(args);

        // Set encrypted secrets if configured
        if (encryptedSecretsRef.length > 0) {
            req.addSecretsReference(encryptedSecretsRef);
        }

        // Send to Chainlink DON
        requestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            callbackGasLimit,
            DON_ID
        );

        // Store request
        _requests[requestId] = InferenceRequest({
            requestId:   requestId,
            agentId:     agentId,
            taskId:      taskId,
            prompt:      prompt,
            response:    "",
            rawResponse: "",
            status:      InferenceStatus.PENDING,
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

    // ============================================================
    //                    CHAINLINK CALLBACK
    // ============================================================

    /// @notice Called by Chainlink DON when inference completes
    /// @dev Overrides FunctionsClient._fulfillRequest()
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        InferenceRequest storage req = _requests[requestId];

        // Silently ignore unknown requests (shouldn't happen)
        if (req.requestedAt == 0) return;

        uint256 agentId = _requestToAgent[requestId];
        req.fulfilledAt = block.timestamp;
        req.rawResponse = response;

        if (err.length > 0) {
            req.status    = InferenceStatus.FAILED;
            req.errorData = err;
            emit InferenceFailed(requestId, agentId, err);
        } else {
            req.status   = InferenceStatus.FULFILLED;
            req.response = string(response);
            emit InferenceFulfilled(requestId, agentId, string(response));
        }
    }

    // ============================================================
    //                     VIEW FUNCTIONS
    // ============================================================

    function getRequest(bytes32 requestId)
        external view override returns (InferenceRequest memory)
    {
        if (_requests[requestId].requestedAt == 0) revert RequestNotFound(requestId);
        return _requests[requestId];
    }

    function getAgentRequests(uint256 agentId)
        external view override returns (bytes32[] memory)
    {
        return _agentRequests[agentId];
    }

    function getTaskInference(bytes32 taskId)
        external view override returns (bytes32)
    {
        return _taskInference[taskId];
    }

    // ============================================================
    //                      ADMIN FUNCTIONS
    // ============================================================

    function setSubscriptionId(uint64 _subId) external onlyOwner {
        subscriptionId = _subId;
        emit SubscriptionUpdated(_subId);
    }

    function setCallbackGasLimit(uint32 _gasLimit) external onlyOwner {
        callbackGasLimit = _gasLimit;
        emit GasLimitUpdated(_gasLimit);
    }

    function setJsSource(string calldata _jsSource) external onlyOwner {
        jsSource = _jsSource;
    }

    function setEncryptedSecretsRef(bytes calldata _ref) external onlyOwner {
        encryptedSecretsRef = _ref;
    }
}
