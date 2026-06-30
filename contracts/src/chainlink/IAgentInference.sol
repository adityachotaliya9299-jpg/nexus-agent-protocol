// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAgentInference
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Interface for on-chain AI inference requests via Chainlink Functions.
///
/// @dev Flow:
///   1. Agent owner calls requestInference(agentId, prompt, taskId)
///      → contract sends Chainlink Functions request to DON
///      → DON executes JavaScript that calls an LLM API (e.g. OpenAI)
///      → DON returns response bytes on-chain
///   2. Chainlink DON calls fulfillRequest(requestId, response, err)
///      → contract stores result, emits InferenceFulfilled
///      → agent can read result and submit to marketplace as proof of AI work
///
///   The Chainlink Functions JavaScript source (stored off-chain, hash on-chain):
///     const prompt = args[0];
///     const response = await Functions.makeHttpRequest({
///       url: "https://api.openai.com/v1/chat/completions",
///       method: "POST",
///       headers: { Authorization: `Bearer ${secrets.apiKey}` },
///       data: { model: "gpt-4o-mini", messages: [{ role: "user", content: prompt }] }
///     });
///     return Functions.encodeString(response.data.choices[0].message.content);
///
///   Sepolia Chainlink Functions:
///     Router:    0xb83E47C2bC239B3bf370bc41e1459A34b41238D0
///     DON ID:    fun-ethereum-sepolia-1
///     Sub ID:    created via functions.chain.link
interface IAgentInference {

    // ============================================================
    //                         ENUMS
    // ============================================================

    enum InferenceStatus {
        PENDING,    // Request sent to Chainlink DON
        FULFILLED,  // Response received
        FAILED      // Error returned from DON
    }

    // ============================================================
    //                         STRUCTS
    // ============================================================

    struct InferenceRequest {
        bytes32 requestId;      // Chainlink Functions request ID
        uint256 agentId;
        bytes32 taskId;         // Optional: link inference to a marketplace task
        string  prompt;         // What the agent asked
        string  response;       // LLM response (empty until fulfilled)
        bytes   rawResponse;    // Raw bytes from DON
        InferenceStatus status;
        uint256 requestedAt;
        uint256 fulfilledAt;
        bytes   errorData;      // Non-empty if status == FAILED
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event InferenceRequested(
        bytes32 indexed requestId,
        uint256 indexed agentId,
        bytes32 indexed taskId,
        string prompt
    );
    event InferenceFulfilled(
        bytes32 indexed requestId,
        uint256 indexed agentId,
        string response
    );
    event InferenceFailed(
        bytes32 indexed requestId,
        uint256 indexed agentId,
        bytes error
    );
    event SubscriptionUpdated(uint64 subscriptionId);
    event GasLimitUpdated(uint32 gasLimit);

    // ============================================================
    //                         ERRORS
    // ============================================================

    error NotAuthorized();
    error ZeroAddress();
    error AgentNotFound(uint256 agentId);
    error RequestNotFound(bytes32 requestId);
    error EmptyPrompt();
    error SubscriptionNotSet();
    error RequestAlreadyFulfilled(bytes32 requestId);

    // ============================================================
    //                     CORE FUNCTIONS
    // ============================================================

    /// @notice Agent owner triggers an AI inference request
    function requestInference(
        uint256 agentId,
        string calldata prompt,
        bytes32 taskId
    ) external returns (bytes32 requestId);

    // ============================================================
    //                     VIEW FUNCTIONS
    // ============================================================

    function getRequest(bytes32 requestId) external view returns (InferenceRequest memory);
    function getAgentRequests(uint256 agentId) external view returns (bytes32[] memory);
    function getTaskInference(bytes32 taskId) external view returns (bytes32 requestId);
    function totalRequests() external view returns (uint256);
    function subscriptionId() external view returns (uint64);
    function callbackGasLimit() external view returns (uint32);
}
