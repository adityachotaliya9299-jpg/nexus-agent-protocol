import "dotenv/config";

export interface RuntimeConfig {
  // Chain
  rpcUrl:      string;
  chainId:     number;
  privateKey:  `0x${string}`;

  // AI
  groqApiKey:  string;
  llmModel:    string;

  // Agent identity
  agentCategory:    string;
  agentMetadataURI: string;
  agentName:        string;

  // Strategy tuning
  maxActiveBids:     number;   // Max concurrent bids
  minRewardEth:      string;   // Min task reward to bid on
  maxDeadlineHours:  number;   // Skip tasks expiring too soon
  pollIntervalMs:    number;   // How often to poll for new tasks
  stakeAmountEth:    string;   // Auto-stake this much on startup

  // Contracts (defaults to Sepolia)
  contracts: {
    AgentRegistry:      `0x${string}`;
    TaskMarketplace:    `0x${string}`;
    ReputationOracle:   `0x${string}`;
    AgentStaking:       `0x${string}`;
    AgentComposability: `0x${string}`;
    ZKEscrow:           `0x${string}`;
    AgentIdentityNFT:   `0x${string}`;
    AgentSkillNFT:      `0x${string}`;
  };
}

function required(key: string): string {
  const val = process.env[key];
  if (!val) throw new Error(`Missing required env var: ${key}`);
  return val;
}

function optional(key: string, fallback: string): string {
  return process.env[key] ?? fallback;
}

export function loadConfig(): RuntimeConfig {
  return {
    rpcUrl:      required("SEPOLIA_RPC_URL"),
    chainId:     11155111,
    privateKey:  required("PRIVATE_KEY") as `0x${string}`,
    groqApiKey:  required("GROQ_API_KEY"),
    llmModel:    optional("LLM_MODEL", "llama-3.1-8b-instant"),

    agentCategory:    optional("AGENT_CATEGORY", "CODE"),
    agentMetadataURI: optional("AGENT_METADATA_URI", "ipfs://QmNexusAgentRuntime"),
    agentName:        optional("AGENT_NAME", "NexusBot"),

    maxActiveBids:    parseInt(optional("MAX_ACTIVE_BIDS",    "3")),
    minRewardEth:     optional("MIN_REWARD_ETH",              "0.001"),
    maxDeadlineHours: parseInt(optional("MAX_DEADLINE_HOURS", "168")),
    pollIntervalMs:   parseInt(optional("POLL_INTERVAL_MS",   "30000")),
    stakeAmountEth:   optional("STAKE_AMOUNT_ETH",            "0"),

    contracts: {
      AgentRegistry:      "0x68F76277A7a8991CE7ac7182AAA10a356dAaB48F",
      TaskMarketplace:    "0x16B3cD374B3596635A76D874c1A3138e7236C76e",
      ReputationOracle:   "0x7deC5525AC26Bcf134c5e8cD7485c16CBC00EeDA",
      AgentStaking:       "0x30852aE83c52a6140A64F63d62d5AeA284d3e723",
      AgentComposability: "0x4628ba31A9264e7eA204b62849e17AF5E10b1f55",
      ZKEscrow:           "0x2EcD5ce3d5140aB7Df3063aAB817AF1336d04416",
      AgentIdentityNFT:   "0xB09a7a641dBF6c8cB0430EDA307e48eAdFa9EA50",
      AgentSkillNFT:      "0x8f45Bd7d2FFa5fB1c17612D4CcE89c1d9d4746A4",
    },
  };
}