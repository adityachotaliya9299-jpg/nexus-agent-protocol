"use client";

import Link from "next/link";
import { useState } from "react";
import { useAccount } from "wagmi";
import { ArrowLeft } from "lucide-react";
import { PageHero, Field } from "@/components/ui/Primitives";
import { Reveal } from "@/components/fx/Reveal";
import { TxButton } from "@/components/wallet/TxButton";
import { useCreateSubTask } from "@/lib/hooks/useAgentComposability";

const HEX32 = /^0x[0-9a-fA-F]{64}$/;

export default function CreateSubTaskPage() {
  const { isConnected } = useAccount();
  const { createSubTask, isPending, isConfirming, isSuccess, error } = useCreateSubTask();

  const [parentTaskId, setParentTaskId] = useState("");
  const [parentAgentId, setParentAgentId] = useState("");
  const [metadataURI, setMetadataURI] = useState("");
  const [deadline, setDeadline] = useState("");
  const [splitBps, setSplitBps] = useState("5000");
  const [reward, setReward] = useState("");

  const split = Number(splitBps || 0);
  const valid =
    HEX32.test(parentTaskId) &&
    Number(parentAgentId) > 0 &&
    metadataURI.length > 0 &&
    !!deadline &&
    split > 0 &&
    split <= 10000 &&
    parseFloat(reward || "0") > 0;

  const submit = () => {
    const ts = Math.floor(new Date(deadline).getTime() / 1000);
    createSubTask(parentTaskId as `0x${string}`, Number(parentAgentId), metadataURI, ts, split, reward);
  };

  return (
    <div>
      <PageHero
        eyebrow="Composability · New"
        title="Delegate a"
        accent="slice of work"
        blurb="Fund a sub-task from your parent task. The sub-agent's share is enforced by the contract — when you approve their work, the split pays out instantly."
        actions={
          <Link href="/dashboard/subtasks" className="btn-ghost">
            <ArrowLeft size={15} /> All sub-tasks
          </Link>
        }
      />

      <div className="ag-section py-12 max-w-2xl">
        <Reveal className="ag-panel p-6 space-y-5">
          <Field label="Parent task ID (bytes32)" hint="The marketplace task you're assigned to.">
            <input className="input font-mono" placeholder="0x…" value={parentTaskId} onChange={(e) => setParentTaskId(e.target.value.trim())} />
          </Field>

          <div className="grid sm:grid-cols-2 gap-5">
            <Field label="Your agent ID (parent)">
              <input className="input" type="number" min="1" placeholder="#" value={parentAgentId} onChange={(e) => setParentAgentId(e.target.value)} />
            </Field>
            <Field label="Reward (ETH)" hint="Locked now, split on approval.">
              <input className="input" type="number" min="0" step="0.001" placeholder="0.05" value={reward} onChange={(e) => setReward(e.target.value)} />
            </Field>
          </div>

          <Field label="Metadata URI" hint="IPFS/Arweave JSON describing the sub-task.">
            <input className="input" placeholder="ipfs://…" value={metadataURI} onChange={(e) => setMetadataURI(e.target.value)} />
          </Field>

          <div className="grid sm:grid-cols-2 gap-5">
            <Field label="Deadline">
              <input type="datetime-local" className="input" value={deadline} onChange={(e) => setDeadline(e.target.value)} />
            </Field>
            <Field label={`Sub-agent split — ${(split / 100).toFixed(1)}%`} hint="Basis points (5000 = 50%).">
              <input
                type="range"
                min="500"
                max="10000"
                step="100"
                value={splitBps}
                onChange={(e) => setSplitBps(e.target.value)}
                className="w-full accent-[#F2A93B] mt-3"
              />
            </Field>
          </div>

          <TxButton
            onClick={submit}
            disabled={!isConnected || !valid}
            isPending={isPending}
            isConfirming={isConfirming}
            isSuccess={isSuccess}
            className="btn-primary w-full"
            successText="Sub-task created ✓"
          >
            {isConnected ? "Create & fund sub-task" : "Connect wallet first"}
          </TxButton>

          {error && <p className="text-xs text-blood break-all">{error.message.split("\n")[0]}</p>}
          {isSuccess && (
            <p className="text-xs text-jade">
              Created. Grab the subTaskId from the transaction&apos;s SubTaskCreated event, then assign a sub-agent from the
              {" "}<Link href="/dashboard/subtasks" className="underline">sub-tasks page</Link>.
            </p>
          )}
        </Reveal>
      </div>
    </div>
  );
}
