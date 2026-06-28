// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentNFT} from "./IAgentNFT.sol";
import {IAgentRegistry} from "../interfaces/IAgentRegistry.sol";
import {IReputationOracle} from "../interfaces/IReputationOracle.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title AgentIdentityNFT
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice Soulbound ERC-721 identity NFT for every Nexus agent.
///
/// @dev One NFT per agent. tokenId == agentId.
///      Soulbound: transfers are blocked after minting.
///      Metadata is fully on-chain SVG — no IPFS dependency for the NFT itself.
///      SVG renders the agent's tier, reputation score, and category on a
///      dark card with Nexus branding.
///
///      Reputation tiers:
///        0–1999   → Novice    (gray)
///        2000–3999 → Rising   (green)
///        4000–5999 → Established (teal)
///        6000–7999 → Advanced (blue)
///        8000–9999 → Expert   (purple)
///        10000     → Elite    (gold)
contract AgentIdentityNFT is IAgentNFT, ERC721 {
    using Strings for uint256;

    // ============================================================
    //                         STORAGE
    // ============================================================

    address public immutable protocolOwner;
    address public immutable registry;
    address public immutable reputationOracle;

    /// @notice Addresses authorized to mint (registry integration contract)
    mapping(address => bool) public isMinter;

    /// @notice agentId => minted
    mapping(uint256 => bool) private _agentMinted;

    /// @notice Category names for metadata
    string[6] private _categoryNames = [
        "General", "Code", "Research", "Trading", "Creative", "Orchestrator"
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
        address _registry,
        address _reputationOracle
    ) ERC721("Nexus Agent Identity", "NAGENT") {
        if (_protocolOwner == address(0) || _registry == address(0) ||
            _reputationOracle == address(0)) revert ZeroAddress();

        protocolOwner    = _protocolOwner;
        registry         = _registry;
        reputationOracle = _reputationOracle;
    }

    // ============================================================
    //                      MINT IDENTITY NFT
    // ============================================================

    /// @notice Mint identity NFT for a registered agent
    /// @dev tokenId = agentId (1:1). Soulbound after mint.
    function mintAgentNFT(uint256 agentId, address owner)
        external override onlyMinter returns (uint256 tokenId)
    {
        if (owner == address(0)) revert ZeroAddress();
        if (_agentMinted[agentId]) revert AlreadyMinted(agentId);

        tokenId = agentId;
        _agentMinted[agentId] = true;
        _safeMint(owner, tokenId);

        emit AgentNFTMinted(agentId, owner, tokenId);
    }

    // ============================================================
    //                  SKILL BADGE (stub — see AgentSkillNFT)
    // ============================================================

    /// @notice Not implemented on identity contract — use AgentSkillNFT
    function recordSkillCompletion(uint256, uint256) external pure override {
        revert NotAuthorized();
    }

    // ============================================================
    //                     SOULBOUND ENFORCEMENT
    // ============================================================

    /// @notice Block all transfers (soulbound)
    function _update(address to, uint256 tokenId, address auth)
        internal override returns (address)
    {
        address from = _ownerOf(tokenId);
        // Allow minting (from == address(0)) but block transfers
        if (from != address(0) && to != address(0)) revert Soulbound();
        return super._update(to, tokenId, auth);
    }

    // ============================================================
    //                    ON-CHAIN SVG METADATA
    // ============================================================

    function tokenURI(uint256 tokenId) public view override(ERC721, IAgentNFT) returns (string memory) {
        if (!_agentMinted[tokenId]) revert TokenNotFound(tokenId);

        uint256 agentId = tokenId;
        uint256 score   = _getScore(agentId);
        string memory tierName = _getTierName(score);
        string memory tierColor = _getTierColor(score);
        string memory category = _getCategory(agentId);

        string memory svg = _buildSVG(agentId, score, tierName, tierColor, category);
        string memory json = string(abi.encodePacked(
            '{"name":"Nexus Agent #', agentId.toString(),
            '","description":"On-chain AI agent identity for the Nexus Protocol.",',
            '"attributes":[',
                '{"trait_type":"Agent ID","value":', agentId.toString(), '},',
                '{"trait_type":"Reputation","value":', score.toString(), '},',
                '{"trait_type":"Tier","value":"', tierName, '"},',
                '{"trait_type":"Category","value":"', category, '"}',
            '],',
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '"}'
        ));

        return string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
        ));
    }

    function _buildSVG(
        uint256 agentId,
        uint256 score,
        string memory tierName,
        string memory tierColor,
        string memory category
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 400">',
            '<defs>',
            '<linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">',
            '<stop offset="0%" style="stop-color:#0a0a0f"/>',
            '<stop offset="100%" style="stop-color:#1a1a2e"/>',
            '</linearGradient>',
            '</defs>',
            '<rect width="300" height="400" rx="16" fill="url(#bg)"/>',
            '<rect width="300" height="4" rx="2" fill="', tierColor, '" opacity="0.8"/>',
            // Title
            '<text x="20" y="40" font-family="monospace" font-size="11" fill="#888">NEXUS AGENT PROTOCOL</text>',
            // Agent ID
            '<text x="20" y="80" font-family="monospace" font-size="28" font-weight="bold" fill="white">#',
            agentId.toString(),
            '</text>',
            // Tier badge
            '<rect x="20" y="100" width="80" height="24" rx="12" fill="', tierColor, '" opacity="0.2"/>',
            '<text x="60" y="116" font-family="monospace" font-size="10" fill="', tierColor, '" text-anchor="middle">', tierName, '</text>',
            // Category
            '<text x="20" y="160" font-family="monospace" font-size="11" fill="#666">CATEGORY</text>',
            '<text x="20" y="182" font-family="monospace" font-size="16" fill="#ccc">', category, '</text>',
            // Reputation
            '<text x="20" y="230" font-family="monospace" font-size="11" fill="#666">REPUTATION</text>',
            '<text x="20" y="252" font-family="monospace" font-size="24" font-weight="bold" fill="', tierColor, '">',
            score.toString(),
            '</text>',
            '<text x="110" y="252" font-family="monospace" font-size="12" fill="#555">/ 10000</text>',
            // Rep bar background
            '<rect x="20" y="265" width="260" height="6" rx="3" fill="#222"/>',
            // Rep bar fill (score/10000 * 260)
            '<rect x="20" y="265" width="',
            _scoreToBarWidth(score),
            '" height="6" rx="3" fill="', tierColor, '"/>',
            // Footer
            '<text x="20" y="360" font-family="monospace" font-size="9" fill="#333">nexusagent.vercel.app</text>',
            '<text x="280" y="360" font-family="monospace" font-size="9" fill="#333" text-anchor="end">SEPOLIA</text>',
            '</svg>'
        ));
    }

    function _scoreToBarWidth(uint256 score) internal pure returns (string memory) {
        uint256 width = (score * 260) / 10000;
        if (width < 4) width = 4; // min visible width
        return width.toString();
    }

    function _getTierName(uint256 score) internal pure returns (string memory) {
        if (score >= 10000) return "ELITE";
        if (score >= 8000)  return "EXPERT";
        if (score >= 6000)  return "ADVANCED";
        if (score >= 4000)  return "ESTABLISHED";
        if (score >= 2000)  return "RISING";
        return "NOVICE";
    }

    function _getTierColor(uint256 score) internal pure returns (string memory) {
        if (score >= 10000) return "#FFD700"; // gold
        if (score >= 8000)  return "#A855F7"; // purple
        if (score >= 6000)  return "#3B82F6"; // blue
        if (score >= 4000)  return "#14B8A6"; // teal
        if (score >= 2000)  return "#22C55E"; // green
        return "#6B7280";                      // gray
    }

    function _getCategory(uint256 agentId) internal view returns (string memory) {
        try IAgentRegistry(registry).getAgent(agentId) returns (
            IAgentRegistry.AgentProfile memory profile
        ) {
            uint256 cat = uint256(profile.category);
            if (cat < 6) return _categoryNames[cat];
            return "Unknown";
        } catch {
            return "Unknown";
        }
    }

    function _getScore(uint256 agentId) internal view returns (uint256) {
        try IReputationOracle(reputationOracle).getScore(agentId) returns (uint256 s) {
            return s;
        } catch {
            return 5000;
        }
    }

    // ============================================================
    //                     VIEW FUNCTIONS
    // ============================================================

    function hasIdentityNFT(uint256 agentId) external view override returns (bool) {
        return _agentMinted[agentId];
    }

    function getSkillBadge(uint256, uint256) external pure override returns (IAgentNFT.SkillBadge memory) {
        revert NotAuthorized(); // Use AgentSkillNFT
    }

    function getSkillTier(uint256, uint256) external pure override returns (IAgentNFT.SkillTier) {
        revert NotAuthorized(); // Use AgentSkillNFT
    }

    // ============================================================
    //                      ADMIN FUNCTIONS
    // ============================================================

    function setMinter(address minter, bool authorized) external onlyOwner {
        if (minter == address(0)) revert ZeroAddress();
        isMinter[minter] = authorized;
    }
}
