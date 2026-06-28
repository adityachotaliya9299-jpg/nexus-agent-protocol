// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAgentNFT
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Interface for Agent Identity NFTs (ERC-721) and Skill NFTs (ERC-1155).
///
/// @dev Each registered agent gets one ERC-721 identity NFT.
///      Skill NFTs (ERC-1155) are minted as agents complete tasks in categories.
///
///      Identity NFT:
///        tokenId = agentId (1:1 mapping)
///        Non-transferable (soulbound) — agent identity stays with owner
///        On-chain SVG metadata generated from agentId + reputation score
///
///      Skill NFTs (ERC-1155):
///        tokenId = skill category (matches AgentCategory enum)
///        Amount  = task completions in that category
///        Badge tiers: Bronze(1), Silver(5), Gold(10), Platinum(25), Diamond(50)
///        Transferable — agents can display or delegate skills
interface IAgentNFT {

    // ============================================================
    //                         ENUMS
    // ============================================================

    enum SkillTier {
        NONE,
        BRONZE,    // 1  task
        SILVER,    // 5  tasks
        GOLD,      // 10 tasks
        PLATINUM,  // 25 tasks
        DIAMOND    // 50 tasks
    }

    // ============================================================
    //                         STRUCTS
    // ============================================================

    struct SkillBadge {
        uint256 agentId;
        uint256 category;      // Matches AgentCategory enum
        uint256 completions;   // Total completions in this category
        SkillTier tier;        // Current tier
        uint256 lastUpdatedAt;
    }

    // ============================================================
    //                         EVENTS
    // ============================================================

    event AgentNFTMinted(uint256 indexed agentId, address indexed owner, uint256 tokenId);
    event SkillBadgeMinted(uint256 indexed agentId, uint256 indexed category, SkillTier tier);
    event SkillBadgeUpgraded(uint256 indexed agentId, uint256 indexed category, SkillTier oldTier, SkillTier newTier);
    event BaseURIUpdated(string newBaseURI);

    // ============================================================
    //                         ERRORS
    // ============================================================

    error NotAuthorized();
    error ZeroAddress();
    error AlreadyMinted(uint256 agentId);
    error AgentNotFound(uint256 agentId);
    error TokenNotFound(uint256 tokenId);
    error Soulbound();          // Identity NFT cannot be transferred
    error InvalidCategory(uint256 category);

    // ============================================================
    //                     CORE FUNCTIONS
    // ============================================================

    /// @notice Mint identity NFT for a registered agent (called on registration)
    function mintAgentNFT(uint256 agentId, address owner) external returns (uint256 tokenId);

    /// @notice Mint or upgrade a skill badge NFT (called on task completion)
    function recordSkillCompletion(uint256 agentId, uint256 category) external;

    // ============================================================
    //                     VIEW FUNCTIONS
    // ============================================================

    function getSkillBadge(uint256 agentId, uint256 category) external view returns (SkillBadge memory);
    function getSkillTier(uint256 agentId, uint256 category) external view returns (SkillTier);
    function hasIdentityNFT(uint256 agentId) external view returns (bool);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
