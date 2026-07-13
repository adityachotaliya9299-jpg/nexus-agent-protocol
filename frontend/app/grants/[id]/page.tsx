"use client";

import Link from "next/link";
import { useState } from "react";
import { useParams } from "next/navigation";
import { formatEther } from "viem";
import { ArrowLeft, ThumbsUp, ThumbsDown } from "lucide-react";
import { Reveal } from "@/components/fx/Reveal";
import { Field, InfoRow, Pill, StepTracker } from "@/components/ui/Primitives";
import { TxButton } from "@/components/wallet/TxButton";
import {
  useGrant,
  useVoteOnGrant,
  useFinalizeGrant,
  useExecuteGrant,
  GRANT_TYPES,
  GRANT_STATUS_LABELS,
} from "@/lib/hooks/useCommunityGrants";
import { shortenAddr } from "@/lib/contracts";

const HEX32 = /^0x[0-9a-fA-F]{64}$/;
const ZERO32 = "0x0000000000000000000000000000000000000000000000000000000000000000";
const STATUS_TONES = ["muted", "gold", "jade", "sky", "blood"] as const;

export default function GrantDetailPage() {
  const params = useParams<{ id: string }>();
  const grantId = (params?.id ?? "") as `0x${string}`;
  const validId = HEX32.test(grantId);

  const { data, isLoading, refetch } = useGrant(validId ? grantId : undefined);
  const voteTx = useVoteOnGrant();
  const finalizeTx = useFinalizeGrant();
  const executeTx = useExecuteGrant();
  const [agentId, setAgentId] = useState("");

  const g = data as
    | {
        grantId: `0x${string}`;
        title: string;
        description: string;
        recipient: `0x${string}`;
        amount: bigint;
        grantType: number;
        status: number;
        proposedBy: bigint;
        forVotes: bigint;
        againstVotes: bigint;
        votingEndsAt: bigint;
        proposedAt: bigint;
        executedAt: bigint;
      }
    | undefined;

  const exists = g && g.grantId !== ZERO32;
  const totalVotes = exists ? Number(g!.forVotes + g!.againstVotes) : 0;
  const forPct = totalVotes > 0 ? (Number(g!.forVotes) / totalVotes) * 100 : 0;
  const votingOpen = exists && (g!.status === 0 || g!.status === 1) && Number(g!.votingEndsAt) * 1000 > Date.now();
  // Timeline step: VOTING(0/1) → APPROVED(2) → EXECUTED(3); REJECTED shown as badge
  const step = exists ? (g!.status === 3 ? 3 : g!.status === 2 ? 2 : votingOpen ? 1 : 1) : 0;

  if (!validId) {
    return (
      <div className="ag-section py-24 text-center">
        <h1 className="ag-h1 text-3xl">Invalid grant ID</h1>
        <Link href="/grants" className="btn-secondary mt-8 inline-flex"><ArrowLeft size={15} /> Back to grants</Link>
      </div>
    );
  }

  return (
    <div className="ag-section py-12 space-y-8">
      <Reveal>
        <Link href="/grants" className="btn-ghost -ml-4"><ArrowLeft size={15} /> All grants</Link>
        {exists && (
          <>
            <div className="mt-4 flex flex-wrap items-center gap-3">
              <Pill tone="ember">{GRANT_TYPES[g!.grantType] ?? "?"}</Pill>
              <Pill tone={STATUS_TONES[g!.status] ?? "muted"}>{GRANT_STATUS_LABELS[g!.status] ?? "?"}</Pill>
            </div>
            <h1 className="ag-h1 text-3xl md:text-5xl mt-4">{g!.title || "Untitled grant"}</h1>
          </>
        )}
        <p className="address mt-3">{grantId}</p>
      </Reveal>

      {isLoading && <div className="card p-12 text-center text-text-secondary">Reading grant…</div>}
      {!isLoading && !exists && (
        <div className="card p-12 text-center">
          <h3 className="font-display font-bold text-xl text-bone">No grant found at this ID</h3>
        </div>
      )}

      {exists && (
        <>
          <Reveal className="ag-panel p-6">
            <StepTracker steps={["Proposed", "Voting", "Approved", "Executed"]} current={g!.status === 4 ? 1 : step} />
            {g!.status === 4 && <p className="text-center text-blood text-xs font-mono mt-4 tracking-[0.2em]">REJECTED BY VOTE</p>}
          </Reveal>

          <div className="grid lg:grid-cols-[1.4fr_1fr] gap-8 items-start">
            <Reveal variant="left" className="space-y-6">
              <div className="ag-panel p-6">
                <h3 className="font-display font-bold text-lg text-bone mb-3">Proposal</h3>
                <p className="text-text-secondary leading-relaxed whitespace-pre-wrap">{g!.description || "No description provided."}</p>
                <div className="mt-6">
                  <InfoRow label="Requested">{Number(formatEther(g!.amount)).toFixed(4)} ETH</InfoRow>
                  <InfoRow label="Recipient"><span className="font-mono text-xs">{shortenAddr(g!.recipient)}</span></InfoRow>
                  <InfoRow label="Proposed by">Agent #{g!.proposedBy.toString()}</InfoRow>
                  <InfoRow label="Voting ends">{new Date(Number(g!.votingEndsAt) * 1000).toLocaleString()}</InfoRow>
                </div>
              </div>
            </Reveal>

            <Reveal variant="right" delay={120} className="space-y-6">
              <div className="ag-panel p-6">
                <h3 className="font-display font-bold text-lg text-bone">Votes</h3>
                <div className="mt-4 flex justify-between text-xs font-mono">
                  <span className="text-jade">FOR {Number(g!.forVotes).toLocaleString()}</span>
                  <span className="text-blood">AGAINST {Number(g!.againstVotes).toLocaleString()}</span>
                </div>
                <div className="rep-bar mt-2 h-2">
                  <div className="h-full bg-gradient-to-r from-jade to-jade/70" style={{ width: `${forPct}%` }} />
                </div>
                <p className="text-[11px] text-text-muted mt-2 font-mono">weights = proposer reputation scores</p>

                {votingOpen && (
                  <div className="mt-5 space-y-3">
                    <Field label="Vote as agent #">
                      <input className="input" type="number" min="1" placeholder="Your agent ID" value={agentId} onChange={(e) => setAgentId(e.target.value)} />
                    </Field>
                    <div className="grid grid-cols-2 gap-3">
                      <TxButton
                        onClick={() => voteTx.voteOnGrant(grantId, Number(agentId), true)}
                        disabled={!agentId}
                        isPending={voteTx.isPending}
                        isConfirming={voteTx.isConfirming}
                        isSuccess={voteTx.isSuccess}
                        className="btn-primary"
                        successText="Voted ✓"
                      >
                        <ThumbsUp size={15} /> For
                      </TxButton>
                      <TxButton
                        onClick={() => voteTx.voteOnGrant(grantId, Number(agentId), false)}
                        disabled={!agentId}
                        isPending={voteTx.isPending}
                        isConfirming={voteTx.isConfirming}
                        isSuccess={voteTx.isSuccess}
                        className="btn-secondary"
                        successText="Voted ✓"
                      >
                        <ThumbsDown size={15} /> Against
                      </TxButton>
                    </div>
                  </div>
                )}

                {!votingOpen && (g!.status === 0 || g!.status === 1) && (
                  <TxButton
                    onClick={() => finalizeTx.finalizeGrant(grantId)}
                    isPending={finalizeTx.isPending}
                    isConfirming={finalizeTx.isConfirming}
                    isSuccess={finalizeTx.isSuccess}
                    className="btn-primary w-full mt-5"
                    successText="Finalized ✓"
                  >
                    Finalize vote
                  </TxButton>
                )}

                {g!.status === 2 && (
                  <TxButton
                    onClick={() => executeTx.executeGrant(grantId)}
                    isPending={executeTx.isPending}
                    isConfirming={executeTx.isConfirming}
                    isSuccess={executeTx.isSuccess}
                    className="btn-primary w-full mt-5"
                    successText="Executed — ETH sent ✓"
                  >
                    Execute grant payout
                  </TxButton>
                )}

                {(voteTx.isSuccess || finalizeTx.isSuccess || executeTx.isSuccess) && (
                  <button className="btn-ghost text-xs mt-3" onClick={() => refetch()}>Refresh state</button>
                )}
              </div>
            </Reveal>
          </div>
        </>
      )}
    </div>
  );
}
