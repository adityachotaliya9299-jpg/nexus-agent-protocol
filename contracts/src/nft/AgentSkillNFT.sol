// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentNFT} from "./IAgentNFT.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title AgentSkillNFT
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice ERC-1155 skill badge NFTs. One token type per skill category.
///
/// @dev tokenId = AgentCategory enum value (0–5).
///      Amount held by an address = completions in that category.
///      Tier is derived from amount, not stored separately.
///
///      Skill token IDs:
///        0 = GENERAL
///        1 = CODE
///        2 = RESEARCH
///        3 = TRADING
///        4 = CREATIVE
///        5 = ORCHESTRATOR
///
///      Tier thresholds (completions):
///        1  → BRONZE
///        5  → SILVER
///        10 → GOLD
///        25 → PLATINUM
///        50 → DIAMOND
///
///      On each task completion, marketplace calls recordSkillCompletion()
///      which mints 1 skill token to the agent's wallet.
///      Tier upgrades are tracked and emit events.
contract AgentSkillNFT is IAgentNFT, ERC1155 {
    using Strings for uint256;

    // ============================================================
    //                       CONSTANTS
    // ============================================================

    uint256 public constant NUM_CATEGORIES = 6;

    // Tier thresholds (completions needed)
    uint256 public constant BRONZE_THRESHOLD   = 1;
    uint256 public constant SILVER_THRESHOLD   = 5;
    uint256 public constant GOLD_THRESHOLD     = 10;
    uint256 public constant PLATINUM_THRESHOLD = 25;
    uint256 public constant DIAMOND_THRESHOLD  = 50;

    // ============================================================
    //                         STORAGE
    // ============================================================

    address public immutable protocolOwner;
    address public immutable registry;

    /// @notice Authorized minters (marketplace contract)
    mapping(address => bool) public isMinter;

    /// @notice agentId => category => SkillBadge
    mapping(uint256 => mapping(uint256 => SkillBadge)) private _badges;

    /// @notice agentId => wallet address (for minting)
    mapping(uint256 => address) private _agentWallets;

    string[6] private _categoryNames = [
        "General", "Code", "Research", "Trading", "Creative", "Orchestrator"
    ];

    string[6] private _tierNames = [
        "None", "Bronze", "Silver", "Gold", "Platinum", "Diamond"
    ];

    // ============================================================
    //                       MODIFIERS
    // ============================================================

    modifier onlyOwner() {
        if (msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    modifier onlyMinter() {
        if (!isMinter[msg.sender] && msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    // ============================================================
    //                       CONSTRUCTOR
    // ============================================================

    constructor(
        address _protocolOwner,
        address _registry
    ) ERC1155("") {
        if (_protocolOwner == address(0) || _registry == address(0)) revert ZeroAddress();
        protocolOwner = _protocolOwner;
        registry      = _registry;
    }

    // ============================================================
    //                   RECORD SKILL COMPLETION
    // ============================================================

    /// @notice Record task completion and mint skill badge
    /// @dev Called by marketplace after approveWork().
    ///      Mints to agent's wallet address, not owner EOA.
    function recordSkillCompletion(uint256 agentId, uint256 category)
        external override onlyMinter
    {
        if (category >= NUM_CATEGORIES) revert InvalidCategory(category);

        // Get agent wallet for minting destination
        address wallet = _getAgentWallet(agentId);
        if (wallet == address(0)) return; // No wallet set yet — skip silently

        SkillBadge storage badge = _badges[agentId][category];
        badge.agentId   = agentId;
        badge.category  = category;
        badge.lastUpdatedAt = block.timestamp;

        SkillTier oldTier = badge.tier;
        badge.completions++;

        // Mint 1 skill token to agent wallet
        _mint(wallet, category, 1, "");

        // Check if tier upgraded
        SkillTier newTier = _computeTier(badge.completions);
        badge.tier = newTier;

        if (badge.completions == 1) {
            emit SkillBadgeMinted(agentId, category, newTier);
        } else if (newTier > oldTier) {
            emit SkillBadgeUpgraded(agentId, category, oldTier, newTier);
        }
    }

    // ============================================================
    //                    IDENTITY NFT STUBS
    // ============================================================

    function mintAgentNFT(uint256, address) external pure override returns (uint256) {
        revert NotAuthorized();
    }

    function hasIdentityNFT(uint256) external pure override returns (bool) {
        revert NotAuthorized();
    }

    function tokenURI(uint256) external pure override returns (string memory) {
        revert NotAuthorized();
    }

    // ============================================================
    //                     ERC-1155 METADATA
    // ============================================================

    function uri(uint256 tokenId) public view override returns (string memory) {
        if (tokenId >= NUM_CATEGORIES) return "";
        string memory name = string(abi.encodePacked(_categoryNames[tokenId], " Skill Badge"));
        string memory desc = string(abi.encodePacked(
            "Nexus Protocol skill badge for ", _categoryNames[tokenId], " task completions."
        ));
        string memory json = string(abi.encodePacked(
            '{"name":"', name, '",',
            '"description":"', desc, '",',
            '"attributes":[{"trait_type":"Category","value":"', _categoryNames[tokenId], '"}]}'
        ));
        return string(abi.encodePacked(
            "data:application/json;base64,",
            _base64Encode(bytes(json))
        ));
    }

    // ============================================================
    //                     VIEW FUNCTIONS
    // ============================================================

    function getSkillBadge(uint256 agentId, uint256 category)
        external view override returns (SkillBadge memory)
    {
        return _badges[agentId][category];
    }

    function getSkillTier(uint256 agentId, uint256 category)
        external view override returns (SkillTier)
    {
        return _badges[agentId][category].tier;
    }

    function getCompletions(uint256 agentId, uint256 category)
        external view returns (uint256)
    {
        return _badges[agentId][category].completions;
    }

    function getAllBadges(uint256 agentId)
        external view returns (SkillBadge[] memory badges)
    {
        badges = new SkillBadge[](NUM_CATEGORIES);
        for (uint256 i = 0; i < NUM_CATEGORIES; i++) {
            badges[i] = _badges[agentId][i];
        }
    }

    // ============================================================
    //                      ADMIN FUNCTIONS
    // ============================================================

    function setMinter(address minter, bool authorized) external onlyOwner {
        if (minter == address(0)) revert ZeroAddress();
        isMinter[minter] = authorized;
    }

    /// @notice Register agent wallet for skill token delivery
    /// @dev Called when agent sets their wallet in registry
    function setAgentWallet(uint256 agentId, address wallet) external onlyMinter {
        _agentWallets[agentId] = wallet;
    }

    // ============================================================
    //                     INTERNAL HELPERS
    // ============================================================

    function _computeTier(uint256 completions) internal pure returns (SkillTier) {
        if (completions >= DIAMOND_THRESHOLD)   return SkillTier.DIAMOND;
        if (completions >= PLATINUM_THRESHOLD)  return SkillTier.PLATINUM;
        if (completions >= GOLD_THRESHOLD)      return SkillTier.GOLD;
        if (completions >= SILVER_THRESHOLD)    return SkillTier.SILVER;
        if (completions >= BRONZE_THRESHOLD)    return SkillTier.BRONZE;
        return SkillTier.NONE;
    }

    function _getAgentWallet(uint256 agentId) internal view returns (address) {
        // First check local cache
        if (_agentWallets[agentId] != address(0)) return _agentWallets[agentId];
        // Fall back to registry
        try IAgentRegistry(registry).getAgent(agentId) returns (
            IAgentRegistry.AgentProfile memory profile
        ) {
            return profile.agentWallet;
        } catch {
            return address(0);
        }
    }

    /// @notice Minimal Base64 encoder for on-chain metadata
    function _base64Encode(bytes memory data) internal pure returns (string memory) {
        bytes memory TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        uint256 len = data.length;
        if (len == 0) return "";

        uint256 encodedLen = 4 * ((len + 2) / 3);
        bytes memory result = new bytes(encodedLen);
        uint256 i = 0;
        uint256 j = 0;

        while (i < len) {
            uint256 a = i < len ? uint8(data[i++]) : 0;
            uint256 b = i < len ? uint8(data[i++]) : 0;
            uint256 c = i < len ? uint8(data[i++]) : 0;
            uint256 d = (a << 16) | (b << 8) | c;
            result[j++] = TABLE[(d >> 18) & 0x3F];
            result[j++] = TABLE[(d >> 12) & 0x3F];
            result[j++] = TABLE[(d >> 6)  & 0x3F];
            result[j++] = TABLE[d         & 0x3F];
        }
        if (len % 3 == 1) { result[encodedLen - 1] = "="; result[encodedLen - 2] = "="; }
        else if (len % 3 == 2) { result[encodedLen - 1] = "="; }

        return string(result);
    }
}
