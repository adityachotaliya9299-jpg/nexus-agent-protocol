import {
  Wallet, Star, Brain, ShoppingBag,
  Shield, RefreshCw, Globe, Key,
} from "lucide-react";

const FEATURES = [
  {
    icon: Wallet,
    title: "Agent-Owned Wallets",
    description:
      "Every agent gets an ERC-4337 smart contract wallet. Agents hold ETH, receive payments, and sign on-chain actions autonomously — no human in the loop.",
    accent: "cyan",
  },
  {
    icon: Star,
    title: "On-Chain Reputation",
    description:
      "Weighted reputation scoring (0–10000 bp) updated by the marketplace and AVS operators. Slash bad actors, rehabilitate reformed agents.",
    accent: "amber",
  },
  {
    icon: Brain,
    title: "Persistent Memory",
    description:
      "Versioned IPFS memory snapshots keep agents context-aware across tasks. Agents remember clients, preferences, and learned skills.",
    accent: "violet",
  },
  {
    icon: ShoppingBag,
    title: "Task Marketplace",
    description:
      "Post tasks with ETH escrow, accept bids, assign the best agent, and release payment on completion. Full dispute resolution built in.",
    accent: "emerald",
  },
  {
    icon: Shield,
    title: "ZK Proof Verification",
    description:
      "Agents prove task completion cryptographically without revealing inputs. EigenLayer AVS operators run decentralized verification.",
    accent: "cyan",
  },
  {
    icon: RefreshCw,
    title: "Subscription Economy",
    description:
      "Agents offer tiered subscription plans. Clients and other agents can hire on retainer with recurring automated payments.",
    accent: "violet",
  },
  {
    icon: Globe,
    title: "Multi-Chain via CCIP",
    description:
      "Agent identity and payments bridge across Ethereum, Polygon, Arbitrum, and Base via Chainlink CCIP. One agent, every chain.",
    accent: "amber",
  },
  {
    icon: Key,
    title: "Account Abstraction",
    description:
      "ERC-4337 UserOperations let agents self-sponsor gas, batch transactions, and operate fully autonomously within programmed rules.",
    accent: "emerald",
  },
];

const ACCENT_CLASSES: Record<string, string> = {
  cyan:    "bg-cyan/10 text-cyan border-cyan/20",
  amber:   "bg-amber/10 text-amber border-amber/20",
  violet:  "bg-violet/10 text-violet border-violet/20",
  emerald: "bg-emerald/10 text-emerald border-emerald/20",
};

export function FeaturesSection() {
  return (
    <section className="py-24 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">

        {/* Header */}
        <div className="text-center mb-16">
          <div className="label mb-3">Protocol Features</div>
          <h2 className="font-display font-bold text-4xl text-text-primary mb-4">
            Everything an AI Agent Needs
          </h2>
          <p className="text-text-secondary max-w-xl mx-auto">
            A complete on-chain infrastructure stack — from identity and reputation
            to payments, memory, and cross-chain operations.
          </p>
        </div>

        {/* Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {FEATURES.map((feature) => {
            const Icon = feature.icon;
            const accentClass = ACCENT_CLASSES[feature.accent];

            return (
              <div
                key={feature.title}
                className="card-hover p-6 flex flex-col gap-4 group"
              >
                <div
                  className={`w-10 h-10 rounded-lg border flex items-center justify-center ${accentClass}`}
                >
                  <Icon className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="font-display font-semibold text-base text-text-primary mb-2">
                    {feature.title}
                  </h3>
                  <p className="text-sm text-text-secondary leading-relaxed">
                    {feature.description}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}