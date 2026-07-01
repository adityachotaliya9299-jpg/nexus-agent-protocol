import "dotenv/config";
import { NexusClient } from "../src";
import { createNexusTools, toLangChainTools } from "../src/langchain";
import { ChatGroq } from "@langchain/groq";
import { ChatPromptTemplate } from "@langchain/core/prompts";

const RPC_URL     = process.env.SEPOLIA_RPC_URL ?? "https://ethereum-sepolia-rpc.publicnode.com";
const PRIVATE_KEY = process.env.PRIVATE_KEY as `0x${string}`;
const GROQ_KEY    = process.env.GROQ_API_KEY;

async function main() {
  if (!PRIVATE_KEY || !GROQ_KEY) {
    console.log("Missing env vars"); return;
  }

  const nexus          = NexusClient.withPrivateKey({ rpcUrl: RPC_URL, privateKey: PRIVATE_KEY });
  const nexusTools     = createNexusTools(nexus);
  const langchainTools = toLangChainTools(nexusTools);

  console.log("Nexus tools loaded:", nexusTools.length);

  const llm = new ChatGroq({
    apiKey:      GROQ_KEY,
    model:       "llama-3.1-8b-instant",
    temperature: 0,
  });

  const llmWithTools = llm.bindTools(langchainTools);

  const prompt = ChatPromptTemplate.fromMessages([
    ["system", `You are an autonomous AI agent on Nexus Agent Protocol (Ethereum Sepolia).
Wallet: ${nexus.getAddress()}
Use tools to answer questions about the protocol.`],
    ["human", "{input}"],
  ]);

  const chain = prompt.pipe(llmWithTools);

  const questions = [
    "What are the current Nexus protocol stats?",
    "What is the total number of agents and tasks on the Nexus protocol?",
  ];

  for (const q of questions) {
    console.log("\n" + "=".repeat(50));
    console.log("Q:", q);

    const result = await chain.invoke({ input: q });

    if ((result as any).tool_calls?.length) {
      const call = (result as any).tool_calls[0];
      console.log("Tool called:", call.name);

      const tool = langchainTools.find((t: any) => t.name === call.name);
      if (tool) {
        // Fix: pass empty object if args is null
        const args = call.args ?? {};
        const toolResult = await (tool as any).invoke(args);
        console.log("Result:", toolResult);
      }
    } else {
      console.log("Response:", result.content);
    }
  }
}

main().catch(console.error);
