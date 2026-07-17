// Thin client for the AGORA subgraph on The Graph's hosted studio.
// Only the original four contracts are indexed (registry, oracle,
// marketplace, subscriptions) — newer contracts are read via RPC instead.

// `version/latest` tracks whichever version is currently deployed in Studio,
// so the frontend doesn't break every time the subgraph is redeployed.
export const SUBGRAPH_URL =
  process.env.NEXT_PUBLIC_SUBGRAPH_URL ??
  "https://api.studio.thegraph.com/query/1755484/nexus-agent-protocol/version/latest";

async function gql<T>(query: string, variables?: Record<string, unknown>): Promise<T> {
  const res = await fetch(SUBGRAPH_URL, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ query, variables }),
  });
  if (!res.ok) throw new Error(`subgraph http ${res.status}`);
  const json = await res.json();
  if (json.errors?.length) throw new Error(json.errors[0].message);
  if (json.data == null) throw new Error("subgraph returned no data");
  return json.data as T;
}

// types mirrored from schema.graphql
export interface SgAgent {
  id: string;
  agentId: string;
  owner: string;
  agentWallet: string | null;
  metadataURI: string;
  category: number;
  status: number;
  reputationScore: string;
  totalTasksCompleted: string;
  totalEarned: string;
  registeredAt: string;
  lastActiveAt: string;
}

export interface SgTask {
  id: string;
  taskId: string;
  rawClient: string;
  metadataURI: string;
  reward: string;
  deadline: string;
  createdAt: string;
  status: number;
  minReputation: string;
  resultURI: string | null;
  payment: string | null;
  assignedAgent: { agentId: string } | null;
}

export interface SgBid {
  id: string;
  proposalURI: string;
  active: boolean;
  submittedAt: string;
  agent: { agentId: string; owner: string; reputationScore: string };
}

export interface SgPlan {
  id: string;
  agent: { agentId: string };
  tier: number;
  pricePerPeriod: string;
  periodDuration: string;
  maxSubscribers: string;
  currentSubscribers: string;
  isActive: boolean;
}

export interface SgRepEvent {
  id: string;
  agent: { agentId: string };
  oldScore: string;
  newScore: string;
  delta: string;
  reason: number;
  timestamp: string;
}

// queries
export function fetchTasks(first = 50): Promise<{ tasks: SgTask[] }> {
  return gql(`query Tasks($first: Int!) {
    tasks(first: $first, orderBy: createdAt, orderDirection: desc) {
      id taskId rawClient metadataURI reward deadline createdAt status
      minReputation resultURI payment
      assignedAgent { agentId }
    }
  }`, { first });
}

export function fetchTask(id: string): Promise<{ task: SgTask | null }> {
  return gql(`query Task($id: ID!) {
    task(id: $id) {
      id taskId rawClient metadataURI reward deadline createdAt status
      minReputation resultURI payment
      assignedAgent { agentId }
    }
  }`, { id: id.toLowerCase() });
}

export function fetchBids(taskId: string): Promise<{ bids: SgBid[] }> {
  return gql(`query Bids($task: String!) {
    bids(where: { task: $task }, orderBy: submittedAt, orderDirection: desc) {
      id proposalURI active submittedAt
      agent { agentId owner reputationScore }
    }
  }`, { task: taskId.toLowerCase() });
}

export function fetchAgents(first = 50): Promise<{ agents: SgAgent[] }> {
  return gql(`query Agents($first: Int!) {
    agents(first: $first, orderBy: reputationScore, orderDirection: desc) {
      id agentId owner agentWallet metadataURI category status
      reputationScore totalTasksCompleted totalEarned registeredAt lastActiveAt
    }
  }`, { first });
}

export function fetchAgentTasks(agentId: string): Promise<{ tasks: SgTask[] }> {
  return gql(`query AgentTasks($agent: String!) {
    tasks(where: { assignedAgent: $agent }, orderBy: createdAt, orderDirection: desc) {
      id taskId rawClient metadataURI reward deadline createdAt status
      minReputation resultURI payment
      assignedAgent { agentId }
    }
  }`, { agent: agentId });
}

export function fetchPlans(first = 50): Promise<{ subscriptionPlans: SgPlan[] }> {
  return gql(`query Plans($first: Int!) {
    subscriptionPlans(first: $first, where: { isActive: true }) {
      id tier pricePerPeriod periodDuration maxSubscribers currentSubscribers isActive
      agent { agentId }
    }
  }`, { first });
}

export function fetchActivity(): Promise<{
  tasks: SgTask[];
  reputationEvents: SgRepEvent[];
  agents: SgAgent[];
}> {
  return gql(`query Activity {
    tasks(first: 8, orderBy: createdAt, orderDirection: desc) {
      id taskId rawClient metadataURI reward deadline createdAt status
      minReputation resultURI payment
      assignedAgent { agentId }
    }
    reputationEvents(first: 8, orderBy: timestamp, orderDirection: desc) {
      id oldScore newScore delta reason timestamp
      agent { agentId }
    }
    agents(first: 5, orderBy: registeredAt, orderDirection: desc) {
      id agentId owner agentWallet metadataURI category status
      reputationScore totalTasksCompleted totalEarned registeredAt lastActiveAt
    }
  }`);
}

// task metadata is stored as a URI or inline JSON — make the best of both
export function parseTaskMeta(uri: string, taskId: string): { title: string; description: string; category?: string } {
  const fallback = {
    title: `Task ${taskId.slice(0, 10)}…`,
    description: "Details stored at the task's metadata URI.",
  };
  if (!uri) return fallback;
  const trimmed = uri.trim();
  if (trimmed.startsWith("{")) {
    try {
      const meta = JSON.parse(trimmed);
      return {
        title: meta.title ?? fallback.title,
        description: meta.description ?? fallback.description,
        category: meta.category,
      };
    } catch {
      return fallback;
    }
  }
  if (/^(ipfs|ar|https?):/.test(trimmed)) return fallback;
  // plain-text metadata — some test tasks were posted with just a name
  return { title: trimmed.slice(0, 80), description: trimmed };
}
