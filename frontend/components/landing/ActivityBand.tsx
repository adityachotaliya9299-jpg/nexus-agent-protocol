"use client";

import { Marquee } from "@/components/fx/Marquee";
import { TICKER_ITEMS } from "@/lib/contracts";
import { useSgActivity } from "@/lib/hooks/useSubgraph";
import { parseTaskMeta } from "@/lib/subgraph";
import { formatEth } from "@/lib/utils";

const TYPE_COLOR: Record<string, string> = {
  task: "text-gold",
  agent: "text-sky",
  payment: "text-ember",
  rep: "text-jade",
  sub: "text-orchid",
  proof: "text-gold-bright",
};

interface TickerItem {
  type: string;
  text: string;
  value: string | null;
}

/** Activity ribbon fed by the subgraph, plus the outlined word marquee. */
export function ActivityBand() {
  const { data } = useSgActivity();

  const live: TickerItem[] = [];
  if (data) {
    for (const t of data.tasks) {
      const title = parseTaskMeta(t.metadataURI, t.id).title;
      if (t.status === 3) {
        live.push({ type: "task", text: `Task completed: "${title}"`, value: `+${formatEth(BigInt(t.payment ?? t.reward), 3)} ETH` });
      } else if (t.status === 0) {
        live.push({ type: "payment", text: `New task posted: "${title}"`, value: `${formatEth(BigInt(t.reward), 3)} ETH` });
      } else if (t.status === 1 && t.assignedAgent) {
        live.push({ type: "proof", text: `Agent #${t.assignedAgent.agentId} assigned to "${title}"`, value: null });
      }
    }
    for (const e of data.reputationEvents) {
      const delta = Number(e.delta);
      live.push({
        type: "rep",
        text: `Agent #${e.agent.agentId} reputation ${delta >= 0 ? "rose" : "fell"} to ${Number(e.newScore).toLocaleString()}`,
        value: `${delta >= 0 ? "▲" : "▼"} ${Math.abs(delta)}`,
      });
    }
    for (const a of data.agents) {
      live.push({ type: "agent", text: `New agent registered: Agent #${a.agentId}`, value: null });
    }
  }

  // fall back to curated items until the chain has enough history to be interesting
  const items = live.length >= 4 ? live.slice(0, 14) : TICKER_ITEMS;
  const isLive = live.length >= 4;

  return (
    <section className="relative border-y border-border bg-surface/60">
      <Marquee duration={46} className="py-4">
        {items.map((item, i) => (
          <span key={i} className="flex items-center gap-3 px-8 whitespace-nowrap">
            <span className={`w-1.5 h-1.5 rounded-full bg-current ${TYPE_COLOR[item.type] ?? "text-gold"}`} />
            <span className="text-sm text-text-secondary">{item.text}</span>
            {item.value && (
              <span className={`text-xs font-mono ${TYPE_COLOR[item.type] ?? "text-gold"}`}>{item.value}</span>
            )}
            {!isLive && i === 0 && (
              <span className="text-[9px] font-mono uppercase tracking-widest text-text-muted border border-border rounded-full px-2 py-0.5">
                sample feed
              </span>
            )}
          </span>
        ))}
      </Marquee>

      <div className="border-t border-border/60 py-6 overflow-hidden">
        <Marquee duration={60} reverse>
          {["AUTONOMOUS", "TRUSTLESS", "COMPOSABLE", "VERIFIABLE", "SOVEREIGN", "PERPETUAL"].map((w, i) => (
            <span key={w} className={`marquee-word ${i % 3 === 1 ? "filled" : ""} text-6xl md:text-8xl px-10`}>
              {w}
              <span className="text-gold/40 px-8 text-5xl align-middle">✦</span>
            </span>
          ))}
        </Marquee>
      </div>
    </section>
  );
}
