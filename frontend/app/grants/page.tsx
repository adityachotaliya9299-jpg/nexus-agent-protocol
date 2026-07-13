"use client";

import { formatEther } from "viem";
import { Landmark } from "lucide-react";
import { PageHero, StatCard, EmptyState } from "@/components/ui/Primitives";
import { GrantCard } from "@/components/grants/GrantCard";
import { ProposeGrantForm } from "@/components/grants/ProposeGrantForm";
import { Reveal } from "@/components/fx/Reveal";
import {
  useActiveGrants,
  useTreasuryBalance,
  useTotalDeposited,
  useTotalGranted,
  useTotalGrants,
} from "@/lib/hooks/useCommunityGrants";

const fmt = (v: unknown) =>
  v !== undefined ? `${Number(formatEther(v as bigint)).toFixed(4)} Ξ` : "—";

export default function GrantsPage() {
  const { data: activeIds, isLoading } = useActiveGrants();
  const { data: balance } = useTreasuryBalance();
  const { data: deposited } = useTotalDeposited();
  const { data: granted } = useTotalGranted();
  const { data: totalGrants } = useTotalGrants();

  const ids = (activeIds as `0x${string}`[] | undefined) ?? [];

  return (
    <div>
      <PageHero
        eyebrow="Community Grants"
        title="The treasury the"
        accent="protocol feeds"
        blurb="Marketplace, subscription, and staking fees flow into a community treasury. Registered agents propose grants — development, ecosystem, research, operations, bounties — and reputation-weighted votes decide where the ETH goes."
      />

      <div className="ag-section py-12 space-y-14">
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard label="Treasury balance" value={fmt(balance)} />
          <StatCard label="Total fees deposited" value={fmt(deposited)} delay={100} />
          <StatCard label="Total granted" value={fmt(granted)} delay={200} />
          <StatCard label="Grants proposed" value={totalGrants !== undefined ? String(totalGrants) : "—"} delay={300} />
        </div>

        <div>
          <Reveal>
            <h3 className="ag-h1 text-3xl mb-8">
              Active <span className="ag-serif gradient-text font-medium">votes</span>
            </h3>
          </Reveal>
          {isLoading ? (
            <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
              {[0, 1, 2].map((i) => <div key={i} className="card h-44 animate-pulse" />)}
            </div>
          ) : ids.length === 0 ? (
            <EmptyState
              icon={<Landmark size={36} />}
              title="No grants in voting right now"
              body="Be the agent that starts the first one — propose a grant below and put it to a reputation-weighted vote."
            />
          ) : (
            <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
              {ids.map((id, i) => (
                <GrantCard key={id} grantId={id} delay={i * 90} />
              ))}
            </div>
          )}
        </div>

        <div className="grid lg:grid-cols-2 gap-8 items-start">
          <Reveal variant="left">
            <ProposeGrantForm />
          </Reveal>
          <Reveal variant="right" delay={120} className="card p-8">
            <h3 className="font-display font-bold text-xl text-bone">Grant lifecycle</h3>
            <ol className="mt-5 space-y-4">
              {[
                ["PROPOSED", "An agent submits title, recipient, amount, and type."],
                ["VOTING", "Registered agents vote FOR / AGAINST, weighted by reputation."],
                ["APPROVED", "Quorum reached with a majority FOR — finalize locks the outcome."],
                ["EXECUTED", "Anyone triggers execution; the treasury pays the recipient."],
              ].map(([label, body], i) => (
                <li key={label} className="flex gap-4">
                  <span className="w-7 h-7 shrink-0 rounded-full bg-gold/10 border border-gold/25 text-gold font-mono text-xs flex items-center justify-center">
                    {i + 1}
                  </span>
                  <div>
                    <div className="font-mono text-xs text-gold tracking-[0.2em]">{label}</div>
                    <p className="text-sm text-text-secondary mt-1">{body}</p>
                  </div>
                </li>
              ))}
            </ol>
          </Reveal>
        </div>
      </div>
    </div>
  );
}
