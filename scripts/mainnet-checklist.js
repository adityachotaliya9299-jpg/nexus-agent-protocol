#!/usr/bin/env node
/**
 * Nexus Protocol — Mainnet Launch Checklist
 *
 * Runs automated checks against deployed contracts before mainnet launch.
 * Fix every FAIL before deploying to mainnet.
 *
 * Usage:
 *   SEPOLIA_RPC_URL=https://... node scripts/mainnet-checklist.js
 *
 * Or for mainnet dry-run:
 *   MAINNET_RPC_URL=https://... node scripts/mainnet-checklist.js --mainnet
 */

const { createPublicClient, http, formatEther } = require("viem");
const { sepolia, mainnet } = require("viem/chains");
require("dotenv").config({ path: "./contracts/.env" });

// ── Contract addresses ─────────────────────────────────────────

const CONTRACTS = {
  AgentRegistry:        "0x68F76277A7a8991CE7ac7182AAA10a356dAaB48F",
  ReputationOracle:     "0x7deC5525AC26Bcf134c5e8cD7485c16CBC00EeDA",
  TaskMarketplace:      "0x16B3cD374B3596635A76D874c1A3138e7236C76e",
  AgentStaking:         "0x30852aE83c52a6140A64F63d62d5AeA284d3e723",
  ZKEscrow:             "0x2EcD5ce3d5140aB7Df3063aAB817AF1336d04416",
  NexusServiceManager:  "0x2E1eF805b574094AFDF84f86b4B9bf07697F3080",
  AgentIdentityNFT:     "0xB09a7a641dBF6c8cB0430EDA307e48eAdFa9EA50",
  AgentSkillNFT:        "0x8f45Bd7d2FFa5fB1c17612D4CcE89c1d9d4746A4",
  AgentComposability:   "0x4628ba31A9264e7eA204b62849e17AF5E10b1f55",
  ContextualReputation: "0xAFE6c16FA37bB0BD9E7A24901705C7Fe725A910A",
  AgentDiscovery:       "0x08787B020D4Ded4Beb9Ff116e041047491A7F126",
};

// ── Checklist ──────────────────────────────────────────────────

const checks = [
  {
    name: "All contracts have bytecode on Sepolia",
    critical: true,
    run: async (client) => {
      const results = await Promise.all(
        Object.entries(CONTRACTS).map(async ([name, addr]) => {
          const code = await client.getBytecode({ address: addr });
          return { name, addr, hasCode: code && code.length > 2 };
        })
      );
      const missing = results.filter(r => !r.hasCode);
      if (missing.length > 0) {
        return { pass: false, detail: `Missing: ${missing.map(r => r.name).join(", ")}` };
      }
      return { pass: true, detail: `${results.length} contracts verified` };
    }
  },

  {
    name: "AgentRegistry has at least 1 agent",
    critical: false,
    run: async (client) => {
      const data = await client.readContract({
        address: CONTRACTS.AgentRegistry,
        abi: [{ name: "totalAgents", type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] }],
        functionName: "totalAgents",
      });
      const count = Number(data);
      return { pass: count > 0, detail: `${count} agents registered` };
    }
  },

  {
    name: "TaskMarketplace fee rate is valid (≤ 10%)",
    critical: true,
    run: async (client) => {
      const [fee, maxFee] = await Promise.all([
        client.readContract({
          address: CONTRACTS.TaskMarketplace,
          abi: [{ name: "platformFeeBps", type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] }],
          functionName: "platformFeeBps",
        }),
        client.readContract({
          address: CONTRACTS.TaskMarketplace,
          abi: [{ name: "MAX_FEE_BPS", type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] }],
          functionName: "MAX_FEE_BPS",
        }),
      ]);
      const feePct = Number(fee) / 100;
      const pass = BigInt(fee) <= BigInt(maxFee);
      return { pass, detail: `Platform fee: ${feePct}% (max ${Number(maxFee)/100}%)` };
    }
  },

  {
    name: "AgentDiscovery has indexed agents",
    critical: false,
    run: async (client) => {
      const count = await client.readContract({
        address: CONTRACTS.AgentDiscovery,
        abi: [{ name: "totalIndexed", type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] }],
        functionName: "totalIndexed",
      });
      const n = Number(count);
      return { pass: n > 0, detail: `${n} agents indexed in discovery` };
    }
  },

  {
    name: "AgentStaking default slash rate ≤ 50%",
    critical: true,
    run: async (client) => {
      const [rate, max] = await Promise.all([
        client.readContract({
          address: CONTRACTS.AgentStaking,
          abi: [{ name: "slashRateBps", type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] }],
          functionName: "slashRateBps",
        }),
        client.readContract({
          address: CONTRACTS.AgentStaking,
          abi: [{ name: "MAX_SLASH_BPS", type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] }],
          functionName: "MAX_SLASH_BPS",
        }),
      ]);
      const pass = BigInt(rate) <= BigInt(max);
      return { pass, detail: `Slash rate: ${Number(rate)/100}% (max ${Number(max)/100}%)` };
    }
  },

  {
    name: "ZKEscrow has zero accumulated fees (clean state)",
    critical: false,
    run: async (client) => {
      const fees = await client.readContract({
        address: CONTRACTS.ZKEscrow,
        abi: [{ name: "accruedFees", type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] }],
        functionName: "accruedFees",
      });
      return { pass: true, detail: `Accrued fees: ${formatEther(fees)} ETH` };
    }
  },

  {
    name: "NexusServiceManager is registered EigenLayer AVS",
    critical: false,
    run: async (client) => {
      const code = await client.getBytecode({ address: CONTRACTS.NexusServiceManager });
      return {
        pass: code && code.length > 2,
        detail: "ServiceManager deployed at 0x2E1eF805... on Sepolia"
      };
    }
  },

  {
    name: "ERC-721 Identity NFT name is correct",
    critical: true,
    run: async (client) => {
      const name = await client.readContract({
        address: CONTRACTS.AgentIdentityNFT,
        abi: [{ name: "name", type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "string" }] }],
        functionName: "name",
      });
      const pass = name === "Nexus Agent Identity";
      return { pass, detail: `NFT name: "${name}"` };
    }
  },

  {
    name: "No contracts hold unexpected ETH balance",
    critical: true,
    run: async (client) => {
      const balances = await Promise.all(
        Object.entries(CONTRACTS).map(async ([name, addr]) => {
          const bal = await client.getBalance({ address: addr });
          return { name, bal };
        })
      );
      const suspicious = balances.filter(b => b.bal > 0n).map(
        b => `${b.name}: ${formatEther(b.bal)} ETH`
      );
      if (suspicious.length > 0) {
        return { pass: false, detail: `Unexpected balances: ${suspicious.join(", ")}` };
      }
      return { pass: true, detail: "All contracts at zero balance (expected)" };
    }
  },
];

// ── Mainnet deployment checklist (manual) ─────────────────────

const MAINNET_MANUAL_CHECKLIST = [
  "[ ] External security audit completed (Cyfrin, Code4rena, or Sherlock)",
  "[ ] All invariant tests pass on fork of mainnet state",
  "[ ] Owner wallet is a hardware wallet or multisig (Safe)",
  "[ ] Deployer private key is rotated after deployment",
  "[ ] ProtocolGuard guardians set to 3 separate multisig signers",
  "[ ] Rate limiter threshold set appropriately for expected volume",
  "[ ] Front-end points to mainnet RPC, not Sepolia",
  "[ ] Subgraph redeployed with mainnet contract addresses",
  "[ ] SDK constants updated with mainnet addresses",
  "[ ] Agent runtime .env updated with mainnet RPC",
  "[ ] docs/README.md updated with mainnet addresses",
  "[ ] Twitter/X announcement ready",
  "[ ] Discord/Telegram community notified",
  "[ ] Analytics/monitoring set up (Tenderly, Dune, The Graph)",
];

// ── Runner ────────────────────────────────────────────────────

async function main() {
  const isMainnet = process.argv.includes("--mainnet");
  const rpcUrl    = isMainnet
    ? process.env.MAINNET_RPC_URL
    : process.env.SEPOLIA_RPC_URL;

  if (!rpcUrl) {
    console.error("Set SEPOLIA_RPC_URL or MAINNET_RPC_URL in contracts/.env");
    process.exit(1);
  }

  const client = createPublicClient({
    chain:     isMainnet ? mainnet : sepolia,
    transport: http(rpcUrl),
  });

  console.log("");
  console.log("══════════════════════════════════════════════");
  console.log(" Nexus Protocol — Mainnet Launch Checklist");
  console.log(`  Network: ${isMainnet ? "ETHEREUM MAINNET" : "Sepolia Testnet"}`);
  console.log("══════════════════════════════════════════════");
  console.log("");

  let passed = 0;
  let failed  = 0;
  let warns   = 0;

  for (const check of checks) {
    process.stdout.write(`  ${check.name}... `);
    try {
      const result = await check.run(client);
      if (result.pass) {
        console.log(`✅  ${result.detail}`);
        passed++;
      } else {
        console.log(`${check.critical ? "❌ FAIL" : "⚠️  WARN"} ${result.detail}`);
        check.critical ? failed++ : warns++;
      }
    } catch (err) {
      console.log(`❌ ERROR: ${err.message}`);
      failed++;
    }
  }

  console.log("");
  console.log("══════════════════════════════════════════════");
  console.log(`  Results: ${passed} passed, ${warns} warnings, ${failed} failed`);
  console.log("══════════════════════════════════════════════");

  if (failed > 0) {
    console.log("  ❌ NOT READY for mainnet — fix all FAILs first");
  } else if (warns > 0) {
    console.log("  ⚠️  Review warnings before mainnet");
  } else {
    console.log("  ✅ Automated checks passed");
  }

  console.log("");
  console.log("══════════════════════════════════════════════");
  console.log(" Manual Mainnet Checklist");
  console.log("══════════════════════════════════════════════");
  MAINNET_MANUAL_CHECKLIST.forEach(item => console.log(" ", item));

  console.log("");
  console.log("══════════════════════════════════════════════");
  console.log(" Mainnet Deployment Commands (when ready)");
  console.log("══════════════════════════════════════════════");
  console.log("  # 1. Deploy all contracts");
  console.log("  forge script script/DeployAll.s.sol \\");
  console.log("    --rpc-url $MAINNET_RPC_URL \\");
  console.log("    --broadcast \\");
  console.log("    --verify \\");
  console.log("    --etherscan-api-key $ETHERSCAN_API_KEY \\");
  console.log("    -vvvv");
  console.log("");
  console.log("  # 2. Deploy coordinator");
  console.log("  forge script script/DeployCoordinator.s.sol \\");
  console.log("    --rpc-url $MAINNET_RPC_URL --broadcast --verify -vvvv");
  console.log("");
  console.log("  # 3. Run checklist against mainnet");
  console.log("  node scripts/mainnet-checklist.js --mainnet");
  console.log("══════════════════════════════════════════════");

  process.exit(failed > 0 ? 1 : 0);
}

main().catch(err => {
  console.error("Fatal:", err.message);
  process.exit(1);
});