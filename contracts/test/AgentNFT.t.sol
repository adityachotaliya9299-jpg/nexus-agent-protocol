// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AgentIdentityNFT} from "../src/nft/AgentIdentityNFT.sol";
import {AgentSkillNFT} from "../src/nft/AgentSkillNFT.sol";
import {IAgentNFT} from "../src/nft/IAgentNFT.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";

// ── Stubs ──────────────────────────────────────────────────────

contract MockRegistry {
    mapping(uint256 => address) public owners;
    mapping(uint256 => address) public wallets;
    mapping(uint256 => uint256) public categories;
    mapping(uint256 => bool)    public exists;

    function addAgent(uint256 id, address owner, address wallet, uint256 cat) external {
        owners[id]     = owner;
        wallets[id]    = wallet;
        categories[id] = cat;
        exists[id]     = true;
    }

    function getAgent(uint256 id) external view returns (IAgentRegistry.AgentProfile memory p) {
        require(exists[id], "not found");
        p.agentId     = id;
        p.owner       = owners[id];
        p.agentWallet = wallets[id];
        p.category    = IAgentRegistry.AgentCategory(categories[id]);
        return p;
    }

    function totalAgents() external pure returns (uint256) { return 3; }
}

contract MockOracle {
    mapping(uint256 => uint256) public scores;
    function setScore(uint256 id, uint256 s) external { scores[id] = s; }
    function getScore(uint256 id) external view returns (uint256) {
        return scores[id] == 0 ? 5000 : scores[id];
    }
}

// ── Test contract ──────────────────────────────────────────────

contract AgentNFTTest is Test {
    AgentIdentityNFT internal identityNFT;
    AgentSkillNFT    internal skillNFT;
    MockRegistry     internal registry;
    MockOracle       internal oracle;

    address constant OWNER      = address(0xA11CE);
    address constant MINTER     = address(0x4A3E7); // marketplace
    address constant AGENT_OWN  = address(0xA6E4);
    address constant AGENT_WALL = address(0xWA11);
    address constant STRANGER   = address(0x577A4);

    uint256 constant AGENT_ID   = 1;
    uint256 constant AGENT_ID_2 = 2;

    uint256 constant CAT_GENERAL  = 0;
    uint256 constant CAT_CODE     = 1;
    uint256 constant CAT_RESEARCH = 2;

    function setUp() public {
        registry = new MockRegistry();
        oracle   = new MockOracle();

        vm.startPrank(OWNER);
        identityNFT = new AgentIdentityNFT(OWNER, address(registry), address(oracle));
        skillNFT    = new AgentSkillNFT(OWNER, address(registry));

        identityNFT.setMinter(MINTER, true);
        skillNFT.setMinter(MINTER, true);
        vm.stopPrank();

        registry.addAgent(AGENT_ID,   AGENT_OWN,  AGENT_WALL, CAT_CODE);
        registry.addAgent(AGENT_ID_2, STRANGER,   address(0), CAT_GENERAL);

        oracle.setScore(AGENT_ID, 8500);

        vm.deal(AGENT_OWN, 1 ether);
    }

    // ── Identity NFT: Deployment ─────────────────────────────────

    function test_Identity_Name() public view {
        assertEq(identityNFT.name(), "Nexus Agent Identity");
        assertEq(identityNFT.symbol(), "NAGENT");
    }

    function test_Identity_OwnerSet() public view {
        assertEq(identityNFT.protocolOwner(), OWNER);
    }

    function test_Identity_MinterSet() public view {
        assertTrue(identityNFT.isMinter(MINTER));
    }

    // ── Identity NFT: Minting ────────────────────────────────────

    function test_Identity_Mint_Success() public {
        vm.prank(MINTER);
        uint256 tokenId = identityNFT.mintAgentNFT(AGENT_ID, AGENT_OWN);

        assertEq(tokenId, AGENT_ID);
        assertEq(identityNFT.ownerOf(tokenId), AGENT_OWN);
        assertTrue(identityNFT.hasIdentityNFT(AGENT_ID));
    }

    function test_Identity_Mint_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit IAgentNFT.AgentNFTMinted(AGENT_ID, AGENT_OWN, AGENT_ID);
        vm.prank(MINTER);
        identityNFT.mintAgentNFT(AGENT_ID, AGENT_OWN);
    }

    function test_Identity_Mint_OnlyMinter() public {
        vm.prank(STRANGER);
        vm.expectRevert(IAgentNFT.NotAuthorized.selector);
        identityNFT.mintAgentNFT(AGENT_ID, AGENT_OWN);
    }

    function test_Identity_Mint_DuplicateReverts() public {
        vm.prank(MINTER);
        identityNFT.mintAgentNFT(AGENT_ID, AGENT_OWN);

        vm.prank(MINTER);
        vm.expectRevert(abi.encodeWithSelector(IAgentNFT.AlreadyMinted.selector, AGENT_ID));
        identityNFT.mintAgentNFT(AGENT_ID, AGENT_OWN);
    }

    function test_Identity_Mint_ZeroAddressReverts() public {
        vm.prank(MINTER);
        vm.expectRevert(IAgentNFT.ZeroAddress.selector);
        identityNFT.mintAgentNFT(AGENT_ID, address(0));
    }

    // ── Identity NFT: Soulbound ──────────────────────────────────

    function test_Identity_Transfer_Blocked() public {
        vm.prank(MINTER);
        identityNFT.mintAgentNFT(AGENT_ID, AGENT_OWN);

        vm.prank(AGENT_OWN);
        vm.expectRevert(IAgentNFT.Soulbound.selector);
        identityNFT.transferFrom(AGENT_OWN, STRANGER, AGENT_ID);
    }

    function test_Identity_SafeTransfer_Blocked() public {
        vm.prank(MINTER);
        identityNFT.mintAgentNFT(AGENT_ID, AGENT_OWN);

        vm.prank(AGENT_OWN);
        vm.expectRevert(IAgentNFT.Soulbound.selector);
        identityNFT.safeTransferFrom(AGENT_OWN, STRANGER, AGENT_ID);
    }

    // ── Identity NFT: tokenURI ────────────────────────────────────

    function test_Identity_TokenURI_NotMinted_Reverts() public {
        vm.expectRevert(abi.encodeWithSelector(IAgentNFT.TokenNotFound.selector, AGENT_ID));
        identityNFT.tokenURI(AGENT_ID);
    }

    function test_Identity_TokenURI_ReturnsBase64() public {
        vm.prank(MINTER);
        identityNFT.mintAgentNFT(AGENT_ID, AGENT_OWN);

        string memory uri = identityNFT.tokenURI(AGENT_ID);
        // Should start with data:application/json;base64,
        assertTrue(bytes(uri).length > 0);
        assertEq(_slice(uri, 0, 29), "data:application/json;base64,");
    }

    function test_Identity_TokenURI_ContainsSVG() public {
        vm.prank(MINTER);
        identityNFT.mintAgentNFT(AGENT_ID, AGENT_OWN);

        // URI should be non-empty and valid base64 JSON
        string memory uri = identityNFT.tokenURI(AGENT_ID);
        assertTrue(bytes(uri).length > 100);
    }

    // Tiers based on score
    function test_Identity_TierColors_ExpertScore() public {
        oracle.setScore(AGENT_ID, 8500); // Expert → purple
        vm.prank(MINTER);
        identityNFT.mintAgentNFT(AGENT_ID, AGENT_OWN);
        string memory uri = identityNFT.tokenURI(AGENT_ID);
        assertTrue(bytes(uri).length > 0);
    }

    // ── Skill NFT: Deployment ────────────────────────────────────

    function test_Skill_OwnerSet() public view {
        assertEq(skillNFT.protocolOwner(), OWNER);
    }

    function test_Skill_MinterAuthorized() public view {
        assertTrue(skillNFT.isMinter(MINTER));
    }

    // ── Skill NFT: Record Completion ─────────────────────────────

    function test_Skill_FirstCompletion_MintsBronze() public {
        vm.prank(MINTER);
        skillNFT.recordSkillCompletion(AGENT_ID, CAT_CODE);

        IAgentNFT.SkillBadge memory badge = skillNFT.getSkillBadge(AGENT_ID, CAT_CODE);
        assertEq(badge.completions, 1);
        assertEq(uint256(badge.tier), uint256(IAgentNFT.SkillTier.BRONZE));
    }

    function test_Skill_FirstCompletion_EmitsMintEvent() public {
        vm.expectEmit(true, true, false, true);
        emit IAgentNFT.SkillBadgeMinted(AGENT_ID, CAT_CODE, IAgentNFT.SkillTier.BRONZE);
        vm.prank(MINTER);
        skillNFT.recordSkillCompletion(AGENT_ID, CAT_CODE);
    }

    function test_Skill_FiveCompletions_UpgradesToSilver() public {
        for (uint256 i = 0; i < 4; i++) {
            vm.prank(MINTER);
            skillNFT.recordSkillCompletion(AGENT_ID, CAT_CODE);
        }
        assertEq(uint256(skillNFT.getSkillTier(AGENT_ID, CAT_CODE)), uint256(IAgentNFT.SkillTier.BRONZE));

        vm.expectEmit(true, true, false, true);
        emit IAgentNFT.SkillBadgeUpgraded(AGENT_ID, CAT_CODE, IAgentNFT.SkillTier.BRONZE, IAgentNFT.SkillTier.SILVER);
        vm.prank(MINTER);
        skillNFT.recordSkillCompletion(AGENT_ID, CAT_CODE);

        assertEq(uint256(skillNFT.getSkillTier(AGENT_ID, CAT_CODE)), uint256(IAgentNFT.SkillTier.SILVER));
    }

    function test_Skill_TenCompletions_UpgradesToGold() public {
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(MINTER);
            skillNFT.recordSkillCompletion(AGENT_ID, CAT_CODE);
        }
        assertEq(uint256(skillNFT.getSkillTier(AGENT_ID, CAT_CODE)), uint256(IAgentNFT.SkillTier.GOLD));
    }

    function test_Skill_TwentyFiveCompletions_Platinum() public {
        for (uint256 i = 0; i < 25; i++) {
            vm.prank(MINTER);
            skillNFT.recordSkillCompletion(AGENT_ID, CAT_CODE);
        }
        assertEq(uint256(skillNFT.getSkillTier(AGENT_ID, CAT_CODE)), uint256(IAgentNFT.SkillTier.PLATINUM));
    }

    function test_Skill_FiftyCompletions_Diamond() public {
        for (uint256 i = 0; i < 50; i++) {
            vm.prank(MINTER);
            skillNFT.recordSkillCompletion(AGENT_ID, CAT_CODE);
        }
        assertEq(uint256(skillNFT.getSkillTier(AGENT_ID, CAT_CODE)), uint256(IAgentNFT.SkillTier.DIAMOND));
    }

    function test_Skill_MintsToAgentWallet() public {
        vm.prank(MINTER);
        skillNFT.recordSkillCompletion(AGENT_ID, CAT_CODE);

        // AGENT_WALL should hold 1 skill token of type CAT_CODE
        assertEq(skillNFT.balanceOf(AGENT_WALL, CAT_CODE), 1);
    }

    function test_Skill_OnlyMinter_Reverts() public {
        vm.prank(STRANGER);
        vm.expectRevert(IAgentNFT.NotAuthorized.selector);
        skillNFT.recordSkillCompletion(AGENT_ID, CAT_CODE);
    }

    function test_Skill_InvalidCategory_Reverts() public {
        vm.prank(MINTER);
        vm.expectRevert(abi.encodeWithSelector(IAgentNFT.InvalidCategory.selector, 99));
        skillNFT.recordSkillCompletion(AGENT_ID, 99);
    }

    function test_Skill_NoWallet_SkipsSilently() public {
        // AGENT_ID_2 has no wallet set
        vm.prank(MINTER);
        skillNFT.recordSkillCompletion(AGENT_ID_2, CAT_GENERAL); // Should not revert
        assertEq(skillNFT.getSkillBadge(AGENT_ID_2, CAT_GENERAL).completions, 0);
    }

    function test_Skill_MultipleCategories_Independent() public {
        vm.prank(MINTER);
        skillNFT.recordSkillCompletion(AGENT_ID, CAT_CODE);
        vm.prank(MINTER);
        skillNFT.recordSkillCompletion(AGENT_ID, CAT_RESEARCH);
        vm.prank(MINTER);
        skillNFT.recordSkillCompletion(AGENT_ID, CAT_RESEARCH);

        assertEq(skillNFT.getCompletions(AGENT_ID, CAT_CODE), 1);
        assertEq(skillNFT.getCompletions(AGENT_ID, CAT_RESEARCH), 2);
    }

    function test_Skill_GetAllBadges() public {
        vm.prank(MINTER);
        skillNFT.recordSkillCompletion(AGENT_ID, CAT_CODE);
        vm.prank(MINTER);
        skillNFT.recordSkillCompletion(AGENT_ID, CAT_GENERAL);

        IAgentNFT.SkillBadge[] memory badges = skillNFT.getAllBadges(AGENT_ID);
        assertEq(badges.length, 6);
        assertEq(badges[CAT_CODE].completions, 1);
        assertEq(badges[CAT_GENERAL].completions, 1);
        assertEq(badges[CAT_RESEARCH].completions, 0);
    }

    function test_Skill_URI_ReturnsBase64() public view {
        string memory uri = skillNFT.uri(CAT_CODE);
        assertTrue(bytes(uri).length > 0);
    }

    // ── Skill NFT: Set wallet ────────────────────────────────────

    function test_Skill_SetAgentWallet_UpdatesWallet() public {
        address newWallet = address(0x9999);

        vm.prank(MINTER);
        skillNFT.setAgentWallet(AGENT_ID, newWallet);

        vm.prank(MINTER);
        skillNFT.recordSkillCompletion(AGENT_ID, CAT_CODE);

        assertEq(skillNFT.balanceOf(newWallet, CAT_CODE), 1);
        assertEq(skillNFT.balanceOf(AGENT_WALL, CAT_CODE), 0); // old wallet untouched
    }

    // ── Admin ────────────────────────────────────────────────────

    function test_Identity_SetMinter_OnlyOwner() public {
        vm.prank(STRANGER);
        vm.expectRevert(IAgentNFT.NotAuthorized.selector);
        identityNFT.setMinter(STRANGER, true);
    }

    function test_Skill_SetMinter_OnlyOwner() public {
        vm.prank(STRANGER);
        vm.expectRevert(IAgentNFT.NotAuthorized.selector);
        skillNFT.setMinter(STRANGER, true);
    }

    // ── Fuzz ─────────────────────────────────────────────────────

    function testFuzz_Skill_TierAlwaysMonotonic(uint8 completions) public {
        uint256 n = bound(uint256(completions), 1, 60);
        for (uint256 i = 0; i < n; i++) {
            vm.prank(MINTER);
            skillNFT.recordSkillCompletion(AGENT_ID, CAT_CODE);
        }
        IAgentNFT.SkillTier tier = skillNFT.getSkillTier(AGENT_ID, CAT_CODE);
        IAgentNFT.SkillTier expected = _expectedTier(n);
        assertEq(uint256(tier), uint256(expected));
    }

    function testFuzz_Identity_TokenURI_AnyScore(uint256 score) public {
        score = bound(score, 0, 10000);
        oracle.setScore(AGENT_ID, score);

        vm.prank(MINTER);
        identityNFT.mintAgentNFT(AGENT_ID, AGENT_OWN);

        string memory uri = identityNFT.tokenURI(AGENT_ID);
        assertTrue(bytes(uri).length > 0);
    }

    // ── Internal helpers ──────────────────────────────────────────

    function _expectedTier(uint256 completions) internal pure returns (IAgentNFT.SkillTier) {
        if (completions >= 50) return IAgentNFT.SkillTier.DIAMOND;
        if (completions >= 25) return IAgentNFT.SkillTier.PLATINUM;
        if (completions >= 10) return IAgentNFT.SkillTier.GOLD;
        if (completions >= 5)  return IAgentNFT.SkillTier.SILVER;
        if (completions >= 1)  return IAgentNFT.SkillTier.BRONZE;
        return IAgentNFT.SkillTier.NONE;
    }

    function _slice(string memory s, uint256 start, uint256 len)
        internal pure returns (string memory)
    {
        bytes memory b = bytes(s);
        bytes memory out = new bytes(len);
        for (uint256 i = 0; i < len && start + i < b.length; i++) {
            out[i] = b[start + i];
        }
        return string(out);
    }
}
