"use client";

import { useState } from "react";
import { formatEther } from "viem";
import { Reveal } from "@/components/fx/Reveal";
import { Field, InfoRow, Pill, StepTracker } from "@/components/ui/Primitives";
import { TxButton } from "@/components/wallet/TxButton";
import {
  useSubTask,
  useAssignSubAgent,
  useSubmitSubWork,
  useApproveSubWork,
} from "@/lib/hooks/useAgentComposability";
import { shortenAddr } from "@/lib/contracts";

const HEX32 = /^0x[0-9a-fA-F]{64}$/;
const ZERO32 = "0x0000000000000000000000000000000000000000000000000000000000000000";

const STATUS_TONES = ["gold", "sky", "ember", "jade", "muted"] as const;
const STATUS_LABELS = ["OPEN", "ASSIGNED", "SUBMITTED", "COMPLETED", "CANCELLED"];

/** Look up a sub-task by ID and act on it: assign, submit work, approve. */
export function SubTaskPanel() {
  const [input, setInput] = useState("");
  const [activeId, setActiveId] = useState<`0x${string}` | undefined>();
  const { data: subTask, isLoading, refetch } = useSubTask(activeId);

  const assignTx = useAssignSubAgent();
  const submitTx = useSubmitSubWork();
  const approveTx = useApproveSubWork();

  const [assignId, setAssignId] = useState("");
  const [submitAgentId, setSubmitAgentId] = useState("");
  const [resultURI, setResultURI] = useState("");

  const st = subTask as
    | {
        subTaskId: `0x${string}`;
        parentTaskId: `0x${string}`;
        parentAgentId: bigint;
        subAgentId: bigint;
        metadataURI: string;
        reward: bigint;
        splitBps: bigint;
        deadline: bigint;
        createdAt: bigint;
        completedAt: bigint;
        status: number;
        resultURI: string;
      }
    | undefined;

  const exists = st && st.subTaskId !== ZERO32;
  const step = exists ? Math.min(st!.status, 3) : 0;

  return (
    <div className="space-y-6">
      <Reveal className="ag-panel p-6">
        <h3 className="font-display font-bold text-lg text-bone">Open a sub-task</h3>
        <div className="mt-4 flex gap-3">
          <input
            className="input flex-1 font-mono"
            placeholder="0x… sub-task ID"
            value={input}
            onChange={(e) => setInput(e.target.value.trim())}
          />
          <button
            className={`btn-primary ${!HEX32.test(input) ? "opacity-50 pointer-events-none" : ""}`}
            onClick={() => setActiveId(input as `0x${string}`)}
          >
            Load
          </button>
        </div>
      </Reveal>

      {activeId && isLoading && <div className="card p-10 text-center text-text-secondary">Reading sub-task…</div>}

      {activeId && !isLoading && !exists && (
        <div className="card p-10 text-center">
          <h3 className="font-display font-bold text-lg text-bone">Nothing at this ID</h3>
          <p className="text-sm text-text-secondary mt-1">Check the SubTaskCreated event for the exact bytes32 ID.</p>
        </div>
      )}

      {exists && (
        <Reveal className="ag-panel p-6 space-y-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <h3 className="font-display font-bold text-xl text-bone">Sub-task {shortenAddr(st!.subTaskId)}</h3>
            <Pill tone={STATUS_TONES[st!.status] ?? "muted"}>{STATUS_LABELS[st!.status] ?? "?"}</Pill>
          </div>

          <StepTracker steps={["Open", "Assigned", "Submitted", "Complete"]} current={step} />

          <div>
            <InfoRow label="Parent task"><span className="font-mono text-xs">{shortenAddr(st!.parentTaskId)}</span></InfoRow>
            <InfoRow label="Parent agent">#{st!.parentAgentId.toString()}</InfoRow>
            <InfoRow label="Sub-agent">{st!.subAgentId > BigInt(0) ? `#${st!.subAgentId.toString()}` : "unassigned"}</InfoRow>
            <InfoRow label="Reward">{Number(formatEther(st!.reward)).toFixed(4)} ETH</InfoRow>
            <InfoRow label="Sub-agent split">{(Number(st!.splitBps) / 100).toFixed(1)}%</InfoRow>
            <InfoRow label="Deadline">{new Date(Number(st!.deadline) * 1000).toLocaleString()}</InfoRow>
            {st!.resultURI && <InfoRow label="Result URI">{st!.resultURI}</InfoRow>}
          </div>

          {st!.status === 0 && (
            <div className="grid sm:grid-cols-[1fr_auto] gap-3 items-end">
              <Field label="Assign sub-agent (parent only)">
                <input className="input" type="number" min="1" placeholder="Agent ID from /discover" value={assignId} onChange={(e) => setAssignId(e.target.value)} />
              </Field>
              <TxButton
                onClick={() => assignTx.assignSubAgent(st!.subTaskId, Number(assignId))}
                disabled={!assignId}
                isPending={assignTx.isPending}
                isConfirming={assignTx.isConfirming}
                isSuccess={assignTx.isSuccess}
                successText="Assigned ✓"
              >
                Assign
              </TxButton>
            </div>
          )}

          {st!.status === 1 && (
            <div className="space-y-3">
              <div className="grid sm:grid-cols-2 gap-3">
                <Field label="Your agent ID">
                  <input className="input" type="number" min="1" value={submitAgentId} onChange={(e) => setSubmitAgentId(e.target.value)} />
                </Field>
                <Field label="Result URI">
                  <input className="input" placeholder="ipfs://… or ar://…" value={resultURI} onChange={(e) => setResultURI(e.target.value)} />
                </Field>
              </div>
              <TxButton
                onClick={() => submitTx.submitSubWork(st!.subTaskId, Number(submitAgentId), resultURI)}
                disabled={!submitAgentId || !resultURI}
                isPending={submitTx.isPending}
                isConfirming={submitTx.isConfirming}
                isSuccess={submitTx.isSuccess}
                className="btn-primary w-full"
                successText="Work submitted ✓"
              >
                Submit work (sub-agent)
              </TxButton>
            </div>
          )}

          {st!.status === 2 && (
            <TxButton
              onClick={() => approveTx.approveSubWork(st!.subTaskId)}
              isPending={approveTx.isPending}
              isConfirming={approveTx.isConfirming}
              isSuccess={approveTx.isSuccess}
              className="btn-primary w-full"
              successText="Approved — payment split ✓"
            >
              Approve work & trigger auto-payment
            </TxButton>
          )}

          {(assignTx.isSuccess || submitTx.isSuccess || approveTx.isSuccess) && (
            <button className="btn-ghost text-xs" onClick={() => refetch()}>Refresh state</button>
          )}
        </Reveal>
      )}
    </div>
  );
}
