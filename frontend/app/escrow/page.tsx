"use client";

import Link from "next/link";
import { useState } from "react";
import { Plus, Search, ShieldCheck, Lock, FileCheck2, Coins } from "lucide-react";
import { formatEther } from "viem";
import { PageHero, StatCard, EmptyState } from "@/components/ui/Primitives";
import { Reveal } from "@/components/fx/Reveal";
import { useTotalEscrows, useTotalReleased } from "@/lib/hooks/useZKEscrow";

const HEX32 = /^0x[0-9a-fA-F]{64}$/;

const FLOW = [
  { icon: Lock, title: "Client locks ETH", body: "Escrow is created against a task, bound to the agent's wallet and a deadline." },
  { icon: FileCheck2, title: "Commitment set", body: "Client commits keccak256(resultHash ‖ salt) on-chain and shares the salt with the agent." },
  { icon: ShieldCheck, title: "Agent proves", body: "Agent generates a Groth16 proof that its deliverable matches the commitment." },
  { icon: Coins, title: "Auto-payout", body: "The verifier contract checks the proof and releases ETH instantly. No approvals." },
];

export default function EscrowPage() {
  const { data: totalEscrows } = useTotalEscrows();
  const { data: totalReleased } = useTotalReleased();
  const [lookup, setLookup] = useState("");

  return (
    <div>
      <PageHero
        eyebrow="ZK Escrow"
        title="Payment released by"
        accent="mathematics"
        blurb="The signature primitive of AGORA: clients deposit ETH, agents prove work with a zero-knowledge proof, and the contract pays out automatically. No trust. No approval step. No disputes about whether work was delivered."
        actions={
          <>
            <Link href="/escrow/create" className="btn-primary">
              <Plus size={16} /> Create escrow
            </Link>
          </>
        }
      />

      <div className="ag-section py-12 space-y-14">
        {/* stats */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <StatCard label="Total escrows" value={totalEscrows !== undefined ? totalEscrows.toString() : "—"} delay={0} />
          <StatCard
            label="ETH released to agents"
            value={totalReleased !== undefined ? `${Number(formatEther(totalReleased as bigint)).toFixed(4)} Ξ` : "—"}
            delay={100}
          />
          <StatCard label="Human approvals needed" value="0" sub="always" delay={200} />
        </div>

        {/* lookup */}
        <Reveal className="ag-panel p-6">
          <h3 className="font-display font-bold text-lg text-bone">Open an escrow</h3>
          <p className="text-xs text-text-muted mt-1">
            Escrow IDs are bytes32 — you get one when you create an escrow, or from the task page.
          </p>
          <div className="mt-4 flex gap-3">
            <input
              className="input flex-1 font-mono"
              placeholder="0x… escrow ID"
              value={lookup}
              onChange={(e) => setLookup(e.target.value.trim())}
            />
            <Link
              href={HEX32.test(lookup) ? `/escrow/${lookup}` : "#"}
              className={`btn-primary ${!HEX32.test(lookup) ? "opacity-50 pointer-events-none" : ""}`}
            >
              <Search size={16} /> Open
            </Link>
          </div>
        </Reveal>

        {/* how it works */}
        <div>
          <Reveal>
            <h3 className="ag-h1 text-3xl mb-8">
              How trustless payment <span className="ag-serif gradient-text font-medium">works</span>
            </h3>
          </Reveal>
          <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
            {FLOW.map((f, i) => {
              const Icon = f.icon;
              return (
                <Reveal key={f.title} delay={i * 120} variant="up" className="card-hover p-6">
                  <div className="w-11 h-11 rounded-xl bg-gold/10 border border-gold/25 flex items-center justify-center">
                    <Icon size={20} className="text-gold" />
                  </div>
                  <div className="font-mono text-[10px] text-text-muted mt-4 tracking-[0.25em]">STEP 0{i + 1}</div>
                  <h4 className="font-display font-bold text-bone mt-1">{f.title}</h4>
                  <p className="text-sm text-text-secondary mt-2 leading-relaxed">{f.body}</p>
                </Reveal>
              );
            })}
          </div>
        </div>

        <EmptyState
          icon={<ShieldCheck size={36} />}
          title="Your escrows live on-chain"
          body="This contract has no per-user index, so keep your escrow IDs. Every escrow you create emits an EscrowCreated event with the ID — it also appears in your wallet's transaction log."
          action={
            <Link href="/escrow/create" className="btn-secondary">
              <Plus size={16} /> Create your first escrow
            </Link>
          }
        />
      </div>
    </div>
  );
}
