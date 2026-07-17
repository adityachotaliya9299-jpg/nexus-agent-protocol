"use client";

import Link from "next/link";
import { useState } from "react";
import { useParams } from "next/navigation";
import { formatEther } from "viem";
import { ArrowLeft, ThumbsUp, ThumbsDown } from "lucide-react";
import { Reveal } from "@/components/fx/Reveal";
import { Field, InfoRow, Pill } from "@/components/ui/Primitives";
import { TxButton } from "@/components/wallet/TxButton";
import { RevenueSplitPie } from "@/components/dao/RevenueSplitPie";
import { MemberRow } from "@/components/dao/MemberRow";
import {
  useDAO,
  useDAOMembers,
  useDAOProposal,
  useProposeDAOTask,
  useVoteOnDAOProposal,
  useExecuteDAOProposal,
  useDistributeRevenue,
  PROPOSAL_STATUS_LABELS,
} from "@/lib/hooks/useAgentDAO";
import { shortenAddr } from "@/lib/contracts";

const HEX32 = /^0x[0-9a-fA-F]{64}$/;
const ZERO32 = "0x0000000000000000000000000000000000000000000000000000000000000000";
const PROPOSAL_TONES = ["gold", "jade", "blood", "sky"] as const;

export default function DAODetailPage() {
  const params = useParams<{ id: string }>();
  const daoId = (params?.id ?? "") as `0x${string}`;
  const validId = HEX32.test(daoId);

  const { data: daoData, isLoading } = useDAO(validId ? daoId : undefined);
  const { data: memberIds } = useDAOMembers(validId ? daoId : undefined);

  // proposal panel
  const [proposalInput, setProposalInput] = useState("");
  const [activeProposal, setActiveProposal] = useState<`0x${string}` | undefined>();
  const { data: proposalData, refetch: refetchProposal } = useDAOProposal(activeProposal);

  // forms
  const [taskId, setTaskId] = useState("");
  const [proposerAgentId, setProposerAgentId] = useState("");
  const [voteAgentId, setVoteAgentId] = useState("");
  const [distTaskId, setDistTaskId] = useState("");
  const [distAmount, setDistAmount] = useState("");

  const proposeTx = useProposeDAOTask();
  const voteTx = useVoteOnDAOProposal();
  const executeTx = useExecuteDAOProposal();
  const distributeTx = useDistributeRevenue();

  const dao = daoData as
    | { daoId: `0x${string}`; name: string; treasury: `0x${string}`; totalMembers: bigint; totalTasksCompleted: bigint; totalEarned: bigint; createdAt: bigint; isActive: boolean }
    | undefined;
  const exists = dao && dao.daoId !== ZERO32;

  const proposal = proposalData as
    | { proposalId: `0x${string}`; daoId: `0x${string}`; taskId: `0x${string}`; proposedBy: bigint; forVotes: bigint; againstVotes: bigint; votingEndsAt: bigint; status: number }
    | undefined;
  const proposalExists = proposal && proposal.proposalId !== ZERO32;

  const ids = (memberIds as bigint[] | undefined) ?? [];
  const [splits, setSplits] = useState<Record<string, number>>({});

  if (!validId) {
    return (
      <div className="ag-section py-24 text-center">
        <h1 className="ag-h1 text-3xl">Invalid DAO ID</h1>
        <Link href="/dao" className="btn-secondary mt-8 inline-flex"><ArrowLeft size={15} /> Back to DAOs</Link>
      </div>
    );
  }

  return (
    <div className="ag-section py-12 space-y-8">
      <Reveal>
        <Link href="/dao" className="btn-ghost -ml-4"><ArrowLeft size={15} /> All DAOs</Link>
        <div className="mt-4 flex flex-wrap items-center gap-4">
          <h1 className="ag-h1 text-3xl md:text-5xl">{exists ? dao!.name : "DAO"}</h1>
          {exists && <Pill tone={dao!.isActive ? "jade" : "muted"}>{dao!.isActive ? "ACTIVE" : "INACTIVE"}</Pill>}
        </div>
        <p className="address mt-2">{daoId}</p>
      </Reveal>

      {isLoading && <div className="card p-12 text-center text-text-secondary">Reading DAO…</div>}
      {!isLoading && !exists && (
        <div className="card p-12 text-center">
          <h3 className="font-display font-bold text-xl text-bone">No DAO found at this ID</h3>
        </div>
      )}

      {exists && (
        <>
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <Reveal className="card p-6"><div className="label">Members</div><div className="mt-2 font-display font-bold text-2xl">{dao!.totalMembers.toString()}</div></Reveal>
            <Reveal delay={80} className="card p-6"><div className="label">Tasks completed</div><div className="mt-2 font-display font-bold text-2xl">{dao!.totalTasksCompleted.toString()}</div></Reveal>
            <Reveal delay={160} className="card p-6"><div className="label">Total earned</div><div className="mt-2 font-display font-bold text-2xl text-gold">{Number(formatEther(dao!.totalEarned)).toFixed(4)} ETH</div></Reveal>
            <Reveal delay={240} className="card p-6"><div className="label">Treasury</div><div className="mt-2 font-mono text-sm">{shortenAddr(dao!.treasury)}</div></Reveal>
          </div>

          <div className="grid lg:grid-cols-2 gap-8 items-start">
            {/* members + split */}
            <Reveal variant="left" className="ag-panel p-6">
              <h3 className="font-display font-bold text-lg text-bone mb-4">Members & revenue split</h3>
              {ids.length === 0 ? (
                <p className="text-sm text-text-muted">No members indexed.</p>
              ) : (
                <>
                  <div className="space-y-1 mb-6">
                    {ids.map((id) => (
                      <MemberRow
                        key={id.toString()}
                        daoId={daoId}
                        agentId={Number(id)}
                        onSplit={(bps) => setSplits((s) => (s[id.toString()] === bps ? s : { ...s, [id.toString()]: bps }))}
                      />
                    ))}
                  </div>
                  {Object.keys(splits).length > 0 && (
                    <RevenueSplitPie
                      size={160}
                      slices={Object.entries(splits).map(([id, bps]) => ({ label: `Agent #${id}`, bps }))}
                    />
                  )}
                </>
              )}
            </Reveal>

            {/* proposals */}
            <Reveal variant="right" delay={120} className="space-y-6">
              <div className="ag-panel p-6 space-y-4">
                <h3 className="font-display font-bold text-lg text-bone">Propose a task</h3>
                <Field label="Marketplace task ID">
                  <input className="input font-mono" placeholder="0x…" value={taskId} onChange={(e) => setTaskId(e.target.value.trim())} />
                </Field>
                <Field label="Your agent ID (member)">
                  <input className="input" type="number" min="1" value={proposerAgentId} onChange={(e) => setProposerAgentId(e.target.value)} />
                </Field>
                <TxButton
                  onClick={() => proposeTx.proposeTask(daoId, taskId as `0x${string}`, Number(proposerAgentId))}
                  disabled={!HEX32.test(taskId) || !proposerAgentId}
                  isPending={proposeTx.isPending}
                  isConfirming={proposeTx.isConfirming}
                  isSuccess={proposeTx.isSuccess}
                  className="btn-primary w-full"
                  successText="Proposed — 24h vote opened ✓"
                >
                  Put it to a vote
                </TxButton>
              </div>

              <div className="ag-panel p-6 space-y-4">
                <h3 className="font-display font-bold text-lg text-bone">Open a proposal</h3>
                <div className="flex gap-2">
                  <input className="input flex-1 font-mono" placeholder="0x… proposal ID" value={proposalInput} onChange={(e) => setProposalInput(e.target.value.trim())} />
                  <button
                    className={`btn-secondary ${!HEX32.test(proposalInput) ? "opacity-50 pointer-events-none" : ""}`}
                    onClick={() => setActiveProposal(proposalInput as `0x${string}`)}
                  >
                    Load
                  </button>
                </div>

                {proposalExists && (
                  <div className="pt-2">
                    <div className="flex items-center justify-between">
                      <span className="font-mono text-xs text-text-muted">{shortenAddr(proposal!.proposalId)}</span>
                      <Pill tone={PROPOSAL_TONES[proposal!.status] ?? "muted"}>{PROPOSAL_STATUS_LABELS[proposal!.status]}</Pill>
                    </div>
                    <InfoRow label="Task"><span className="font-mono text-xs">{shortenAddr(proposal!.taskId)}</span></InfoRow>
                    <InfoRow label="Votes">
                      <span className="text-jade">{proposal!.forVotes.toString()} for</span>
                      {" · "}
                      <span className="text-blood">{proposal!.againstVotes.toString()} against</span>
                    </InfoRow>
                    <InfoRow label="Voting ends">{new Date(Number(proposal!.votingEndsAt) * 1000).toLocaleString()}</InfoRow>

                    {proposal!.status === 0 && (
                      <div className="mt-4 space-y-3">
                        <Field label="Vote as agent #">
                          <input className="input" type="number" min="1" value={voteAgentId} onChange={(e) => setVoteAgentId(e.target.value)} />
                        </Field>
                        <div className="grid grid-cols-2 gap-3">
                          <TxButton
                            onClick={() => voteTx.vote(proposal!.proposalId, Number(voteAgentId), true)}
                            disabled={!voteAgentId}
                            isPending={voteTx.isPending}
                            isConfirming={voteTx.isConfirming}
                            isSuccess={voteTx.isSuccess}
                            className="btn-primary"
                            successText="Voted ✓"
                          >
                            <ThumbsUp size={15} /> For
                          </TxButton>
                          <TxButton
                            onClick={() => voteTx.vote(proposal!.proposalId, Number(voteAgentId), false)}
                            disabled={!voteAgentId}
                            isPending={voteTx.isPending}
                            isConfirming={voteTx.isConfirming}
                            isSuccess={voteTx.isSuccess}
                            className="btn-secondary"
                            successText="Voted ✓"
                          >
                            <ThumbsDown size={15} /> Against
                          </TxButton>
                        </div>
                        <TxButton
                          onClick={() => executeTx.executeProposal(proposal!.proposalId)}
                          isPending={executeTx.isPending}
                          isConfirming={executeTx.isConfirming}
                          isSuccess={executeTx.isSuccess}
                          className="btn-secondary w-full"
                          successText="Executed ✓"
                        >
                          Execute (after voting window)
                        </TxButton>
                        <button className="btn-ghost text-xs" onClick={() => refetchProposal()}>Refresh</button>
                      </div>
                    )}
                  </div>
                )}
              </div>

              <div className="ag-panel p-6 space-y-4">
                <h3 className="font-display font-bold text-lg text-bone">Distribute revenue</h3>
                <p className="text-xs text-text-muted -mt-2">Send ETH through the split — every member is paid in one transaction.</p>
                <div className="grid sm:grid-cols-2 gap-3">
                  <Field label="Task ID">
                    <input className="input font-mono" placeholder="0x…" value={distTaskId} onChange={(e) => setDistTaskId(e.target.value.trim())} />
                  </Field>
                  <Field label="Amount (ETH)">
                    <input className="input" type="number" min="0" step="0.001" value={distAmount} onChange={(e) => setDistAmount(e.target.value)} />
                  </Field>
                </div>
                <TxButton
                  onClick={() => distributeTx.distributeRevenue(daoId, distTaskId as `0x${string}`, distAmount)}
                  disabled={!HEX32.test(distTaskId) || parseFloat(distAmount || "0") <= 0}
                  isPending={distributeTx.isPending}
                  isConfirming={distributeTx.isConfirming}
                  isSuccess={distributeTx.isSuccess}
                  className="btn-primary w-full"
                  successText="Distributed ✓"
                >
                  Distribute to all members
                </TxButton>
              </div>
            </Reveal>
          </div>
        </>
      )}
    </div>
  );
}
