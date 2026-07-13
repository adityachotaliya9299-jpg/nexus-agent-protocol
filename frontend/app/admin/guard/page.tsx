"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { formatEther } from "viem";
import { ShieldAlert, ShieldCheck, OctagonPause, Play } from "lucide-react";
import { PageHero, StatCard, Field, EmptyState } from "@/components/ui/Primitives";
import { Reveal } from "@/components/fx/Reveal";
import { TxButton } from "@/components/wallet/TxButton";
import { ContractStatusRow } from "@/components/admin/ContractStatusRow";
import {
  useGuardOwner,
  useRateLimit,
  useTotalInvariants,
  useGuardianCount,
  usePauseContract,
  useUnpauseContract,
  usePauseAll,
  useUnpauseAll,
  useSetRateLimit,
} from "@/lib/hooks/useProtocolGuard";
import { CONTRACTS } from "@/lib/contracts";

const ADDR = /^0x[0-9a-fA-F]{40}$/;

export default function GuardAdminPage() {
  const { address, isConnected } = useAccount();
  const { data: owner } = useGuardOwner();
  const { data: rateLimit } = useRateLimit();
  const { data: totalInvariants } = useTotalInvariants();
  const { data: guardianCount } = useGuardianCount();

  const pauseTx = usePauseContract();
  const unpauseTx = useUnpauseContract();
  const pauseAllTx = usePauseAll();
  const unpauseAllTx = useUnpauseAll();
  const rateTx = useSetRateLimit();

  const [target, setTarget] = useState("");
  const [reason, setReason] = useState("");
  const [duration, setDuration] = useState("24");
  const [unpauseTarget, setUnpauseTarget] = useState("");
  const [windowHours, setWindowHours] = useState("1");
  const [maxOutflow, setMaxOutflow] = useState("10");
  const [globalReason, setGlobalReason] = useState("");

  const isOwner = !!address && !!owner && address.toLowerCase() === (owner as string).toLowerCase();

  const rl = rateLimit as
    | { windowSeconds: bigint; maxOutflowWei: bigint; currentOutflow: bigint; windowStartedAt: bigint }
    | undefined;

  const entries = Object.entries(CONTRACTS) as [string, `0x${string}`][];

  if (!isConnected || !isOwner) {
    return (
      <div>
        <PageHero
          eyebrow="Protocol Guard"
          title="Restricted"
          accent="chamber"
          blurb="The circuit breaker, invariant monitor, and rate limiter for all 22 contracts. Only the protocol owner may operate this console."
        />
        <div className="ag-section py-16 max-w-xl">
          <EmptyState
            icon={<ShieldAlert size={36} />}
            title={isConnected ? "This wallet is not the protocol owner" : "Connect the owner wallet"}
            body={
              isConnected
                ? `Connected as ${address?.slice(0, 8)}… — the ProtocolGuard owner is ${(owner as string | undefined)?.slice(0, 8) ?? "…"}…. Switch accounts to proceed.`
                : "The guard console verifies ownership on-chain before revealing its controls."
            }
          />
        </div>
      </div>
    );
  }

  return (
    <div>
      <PageHero
        eyebrow="Protocol Guard · Owner"
        title="The kill"
        accent="switch"
        blurb="Pause any contract (time-limited, max 7 days), monitor invariants, and keep the ETH outflow rate limiter armed against drain attacks."
      />

      <div className="ag-section py-12 space-y-10">
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard label="Guardians" value={guardianCount !== undefined ? String(guardianCount) : "—"} />
          <StatCard label="Registered invariants" value={totalInvariants !== undefined ? String(totalInvariants) : "—"} delay={80} />
          <StatCard
            label="Rate-limit window"
            value={rl ? `${Number(rl.windowSeconds) / 3600}h` : "—"}
            sub={rl ? `max ${Number(formatEther(rl.maxOutflowWei)).toFixed(2)} ETH out` : undefined}
            delay={160}
          />
          <StatCard
            label="Current outflow"
            value={rl ? `${Number(formatEther(rl.currentOutflow)).toFixed(3)} Ξ` : "—"}
            sub={rl ? `window since ${new Date(Number(rl.windowStartedAt) * 1000).toLocaleTimeString()}` : undefined}
            delay={240}
          />
        </div>

        {/* global controls */}
        <Reveal className="ag-panel p-6 border-blood/30">
          <div className="flex items-center gap-3 mb-4">
            <OctagonPause size={18} className="text-blood" />
            <h3 className="font-display font-bold text-lg text-bone">Protocol-wide circuit breaker</h3>
          </div>
          <div className="grid sm:grid-cols-[1fr_auto_auto] gap-3 items-end">
            <Field label="Reason (public, emitted on-chain)">
              <input className="input" placeholder="e.g. suspected oracle manipulation" value={globalReason} onChange={(e) => setGlobalReason(e.target.value)} />
            </Field>
            <TxButton
              onClick={() => pauseAllTx.pauseAll(globalReason)}
              disabled={!globalReason}
              isPending={pauseAllTx.isPending}
              isConfirming={pauseAllTx.isConfirming}
              isSuccess={pauseAllTx.isSuccess}
              className="btn-primary !bg-blood !text-bone hover:!shadow-[0_0_28px_rgba(229,72,77,0.4)]"
              successText="Protocol paused"
            >
              PAUSE ALL
            </TxButton>
            <TxButton
              onClick={() => unpauseAllTx.unpauseAll()}
              isPending={unpauseAllTx.isPending}
              isConfirming={unpauseAllTx.isConfirming}
              isSuccess={unpauseAllTx.isSuccess}
              className="btn-secondary"
              successText="Protocol live"
            >
              <Play size={15} /> Unpause all
            </TxButton>
          </div>
        </Reveal>

        <div className="grid lg:grid-cols-2 gap-8 items-start">
          {/* contract grid */}
          <Reveal variant="left">
            <h3 className="font-display font-bold text-lg text-bone mb-4 flex items-center gap-2">
              <ShieldCheck size={17} className="text-gold" /> Contract status
            </h3>
            <div className="space-y-2 max-h-[560px] overflow-y-auto pr-1">
              {entries.map(([name, addr]) => (
                <ContractStatusRow key={name} name={name} address={addr} />
              ))}
            </div>
          </Reveal>

          <div className="space-y-6">
            {/* pause form */}
            <Reveal variant="right" className="ag-panel p-6 space-y-4">
              <h3 className="font-display font-bold text-lg text-bone">Pause a contract</h3>
              <Field label="Target address">
                <select className="input" value={target} onChange={(e) => setTarget(e.target.value)}>
                  <option value="">Select contract…</option>
                  {entries.map(([name, addr]) => (
                    <option key={name} value={addr}>{name} — {addr.slice(0, 10)}…</option>
                  ))}
                </select>
              </Field>
              <div className="grid sm:grid-cols-2 gap-4">
                <Field label="Reason">
                  <input className="input" value={reason} onChange={(e) => setReason(e.target.value)} />
                </Field>
                <Field label="Duration (hours, max 168)">
                  <input className="input" type="number" min="1" max="168" value={duration} onChange={(e) => setDuration(e.target.value)} />
                </Field>
              </div>
              <TxButton
                onClick={() => pauseTx.pause(target as `0x${string}`, reason, Number(duration) * 3600)}
                disabled={!ADDR.test(target) || !reason || Number(duration) <= 0 || Number(duration) > 168}
                isPending={pauseTx.isPending}
                isConfirming={pauseTx.isConfirming}
                isSuccess={pauseTx.isSuccess}
                className="btn-primary w-full"
                successText="Paused ✓"
              >
                Pause contract
              </TxButton>

              <div className="ag-divider" />

              <Field label="Unpause target">
                <div className="flex gap-2">
                  <select className="input flex-1" value={unpauseTarget} onChange={(e) => setUnpauseTarget(e.target.value)}>
                    <option value="">Select contract…</option>
                    {entries.map(([name, addr]) => (
                      <option key={name} value={addr}>{name}</option>
                    ))}
                  </select>
                  <TxButton
                    onClick={() => unpauseTx.unpause(unpauseTarget as `0x${string}`)}
                    disabled={!ADDR.test(unpauseTarget)}
                    isPending={unpauseTx.isPending}
                    isConfirming={unpauseTx.isConfirming}
                    isSuccess={unpauseTx.isSuccess}
                    className="btn-secondary"
                    successText="Live ✓"
                  >
                    Unpause
                  </TxButton>
                </div>
              </Field>
            </Reveal>

            {/* rate limiter */}
            <Reveal variant="right" delay={100} className="ag-panel p-6 space-y-4">
              <h3 className="font-display font-bold text-lg text-bone">Rate limiter</h3>
              <p className="text-xs text-text-muted -mt-2">Auto-pauses on excess ETH outflow — drain-attack insurance.</p>
              <div className="grid sm:grid-cols-2 gap-4">
                <Field label="Window (hours)">
                  <input className="input" type="number" min="1" value={windowHours} onChange={(e) => setWindowHours(e.target.value)} />
                </Field>
                <Field label="Max outflow (ETH)">
                  <input className="input" type="number" min="0" step="0.1" value={maxOutflow} onChange={(e) => setMaxOutflow(e.target.value)} />
                </Field>
              </div>
              <TxButton
                onClick={() => rateTx.setRateLimit(Number(windowHours) * 3600, maxOutflow)}
                disabled={Number(windowHours) <= 0 || parseFloat(maxOutflow || "0") <= 0}
                isPending={rateTx.isPending}
                isConfirming={rateTx.isConfirming}
                isSuccess={rateTx.isSuccess}
                className="btn-primary w-full"
                successText="Limit updated ✓"
              >
                Update rate limit
              </TxButton>
            </Reveal>
          </div>
        </div>
      </div>
    </div>
  );
}
