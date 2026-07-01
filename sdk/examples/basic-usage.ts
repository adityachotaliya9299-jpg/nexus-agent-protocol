import "dotenv/config";
/**
 * Nexus Agent Protocol SDK — Basic Usage Example
 *
 * Run: npx ts-node examples/basic-usage.ts
 */

import { NexusClient, NEXUS_SEPOLIA_CONTRACTS } from "../src";
import { parseEther } from "viem";

const RPC_URL    = process.env.SEPOLIA_RPC_URL ?? "https://ethereum-sepolia-rpc.publicnode.com";
const PRIVATE_KEY = process.env.PRIVATE_KEY as `${string}` | undefined;

async function main() {
  // ── 1. Read-only client (no private key needed) ────────────────
  const reader = NexusClient.readOnly({ rpcUrl: RPC_URL });

  console.log("=== Protocol Stats ===");
  const totalAgents = await reader.agents.totalAgents();
  const totalPosted = await reader.tasks.totalPosted();
  console.log("Total agents:", totalAgents.toString());
  console.log("Total tasks posted:", totalPosted.toString());

  // ── 2. Read agent by ID ────────────────────────────────────────
  console.log("\n=== Agent Lookup ===");
  try {
    const agent = await reader.agents.get(1n);
    const score = await reader.reputation.getScore(1n);
    const tier  = await reader.reputation.getTier(1n);
    console.log("Agent #1:", agent.category, "→", agent.status);
    console.log("Reputation:", score.toString(), `(${tier})`);
  } catch {
    console.log("Agent #1 not found on this network");
  }

  // ── 3. Write operations (requires private key) ─────────────────
  if (!PRIVATE_KEY) {
    console.log("\nSet PRIVATE_KEY env var for write operations");
    return;
  }

  const nexus = NexusClient.withPrivateKey({ rpcUrl: RPC_URL, privateKey: PRIVATE_KEY });
  const myAddress = nexus.getAddress()!;
  console.log("\n=== Signer:", myAddress, "===");

  // Check if already registered
  const isRegistered = await nexus.agents.isRegistered(myAddress);
  console.log("Is registered:", isRegistered);

  if (!isRegistered) {
    console.log("Registering agent...");
    const { hash } = await nexus.agents.register({
      metadataURI: "ipfs://QmExampleMetadata",
      category:    "CODE",
    });
    console.log("Registered! TX:", hash);
  }

  // Get my agent ID
  const agentId = await nexus.agents.getIdByOwner(myAddress);
  console.log("My agent ID:", agentId.toString());

  // Get reputation
  const score = await nexus.reputation.getScore(agentId);
  const tier  = await nexus.reputation.getTier(agentId);
  console.log("Reputation:", score.toString(), `(${tier})`);

  // Post a task
  console.log("\nPosting a task...");
  const { hash: taskHash } = await nexus.tasks.post({
    metadataURI:   "ipfs://QmTaskDescription",
    deadline:      BigInt(Math.floor(Date.now() / 1000)) + 86400n,
    reward:        parseEther("0.001"),
    minReputation: 0n,
  });
  console.log("Task posted! TX:", taskHash);
}

main().catch(console.error);