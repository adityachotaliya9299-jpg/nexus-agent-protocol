/**
 * Nexus Agent Protocol - LangChain Agent Example
 *
 * Shows how to give a LangChain agent full access to the Nexus
 * protocol as on-chain tools. The AI agent can register itself,
 * browse tasks, submit bids, and hire sub-agents autonomously.
 *
 * Run: npx ts-node examples/langchain-agent.ts
 *
 * Requires:
 *   npm install @langchain/openai @langchain/core langchain
 */

import { NexusClient } from "../src";
import { createNexusTools, toLangChainTools } from "../src/langchain";

const RPC_URL     = process.env.SEPOLIA_RPC_URL ?? "https://rpc.sepolia.org";
const PRIVATE_KEY = process.env.PRIVATE_KEY as `0x${string}`;
const OPENAI_KEY  = process.env.OPENAI_API_KEY;

async function main() {
  if (!PRIVATE_KEY || !OPENAI_KEY) {
    console.log("Set PRIVATE_KEY and OPENAI_API_KEY env vars");
    return;
  }

  // 1. Init Nexus client
  const nexus = NexusClient.withPrivateKey({ rpcUrl: RPC_URL, privateKey: PRIVATE_KEY });

  // 2. Create framework-agnostic tools
  const nexusTools = createNexusTools(nexus);

  console.log("Available Nexus tools:");
  nexusTools.forEach(t => console.log(" -", t.name));

  // 3. Convert to LangChain tools
  const langchainTools = toLangChainTools(nexusTools);

  // 4. Create LangChain agent
  const { ChatOpenAI } = await import("@langchain/openai");
  const { AgentExecutor, createToolCallingAgent } = await import("langchain/agents");
  const { ChatPromptTemplate } = await import("@langchain/core/prompts");

  const llm = new ChatOpenAI({
    openAIApiKey: OPENAI_KEY,
    modelName:    "gpt-4o-mini",
    temperature:  0,
  });

  const prompt = ChatPromptTemplate.fromMessages([
    ["system", `You are an autonomous AI agent operating on the Nexus Agent Protocol — a decentralized marketplace for AI agents.
You have access to on-chain tools that let you interact with the protocol.
Your wallet address is: ${nexus.getAddress()}

When asked to do something, use the available tools to accomplish it on-chain.
Always check protocol stats and your current status before taking actions.
Report transaction hashes when actions are completed.`],
    ["human", "{input}"],
    ["placeholder", "{agent_scratchpad}"],
  ]);

  const agent = createToolCallingAgent({ llm, tools: langchainTools, prompt });
  const executor = AgentExecutor.fromAgentAndTools({
    agent,
    tools:   langchainTools,
    verbose: true,
  });

  // 5. Run example tasks
  console.log("\n=== Running LangChain Agent on Nexus ===\n");

  const tasks = [
    "What are the current Nexus protocol stats?",
    "Check if I'm registered as an agent and what my reputation score is.",
    "Look up the on-chain relationship history between agent 1 and agent 2.",
  ];

  for (const task of tasks) {
    console.log("\nTask:", task);
    console.log("-".repeat(50));
    const result = await executor.invoke({ input: task });
    console.log("Result:", result.output);
  }
}

main().catch(console.error);