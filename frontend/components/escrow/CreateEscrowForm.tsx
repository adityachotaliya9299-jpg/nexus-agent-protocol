"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { useCreateEscrow } from "@/lib/hooks/useZKEscrow";
import { TxButton } from "@/components/wallet/TxButton";
import { Field } from "@/components/ui/Primitives";

const HEX32 = /^0x[0-9a-fA-F]{64}$/;
const ADDR = /^0x[0-9a-fA-F]{40}$/;

export function CreateEscrowForm() {
  const { isConnected } = useAccount();
  const { createEscrow, isPending, isConfirming, isSuccess, error } = useCreateEscrow();

  const [taskId, setTaskId] = useState("");
  const [agentWallet, setAgentWallet] = useState("");
  const [deadline, setDeadline] = useState("");
  const [reward, setReward] = useState("");

  const valid =
    HEX32.test(taskId) && ADDR.test(agentWallet) && !!deadline && parseFloat(reward || "0") > 0;

  const submit = () => {
    const ts = Math.floor(new Date(deadline).getTime() / 1000);
    createEscrow(taskId as `0x${string}`, agentWallet as `0x${string}`, ts, reward);
  };

  return (
    <div className="ag-panel p-6 space-y-5">
      <div>
        <h3 className="font-display font-bold text-lg text-bone">Escrow parameters</h3>
        <p className="text-xs text-text-muted mt-1">
          ETH locks in the contract until the agent proves the work or the deadline passes.
        </p>
      </div>

      <Field label="Task ID (bytes32)" hint="The marketplace task this escrow pays for.">
        <input className="input font-mono" placeholder="0x…" value={taskId} onChange={(e) => setTaskId(e.target.value.trim())} />
      </Field>

      <Field label="Agent wallet" hint="The agent's ERC-4337 wallet that receives payment on proof.">
        <input className="input font-mono" placeholder="0x…" value={agentWallet} onChange={(e) => setAgentWallet(e.target.value.trim())} />
      </Field>

      <div className="grid sm:grid-cols-2 gap-5">
        <Field label="Deadline" hint="After this, you can refund if no valid proof arrived.">
          <input type="datetime-local" className="input" value={deadline} onChange={(e) => setDeadline(e.target.value)} />
        </Field>
        <Field label="Reward (ETH)">
          <input type="number" min="0" step="0.001" className="input" placeholder="0.10" value={reward} onChange={(e) => setReward(e.target.value)} />
        </Field>
      </div>

      <TxButton
        onClick={submit}
        disabled={!isConnected || !valid}
        isPending={isPending}
        isConfirming={isConfirming}
        isSuccess={isSuccess}
        className="btn-primary w-full"
        successText="Escrow created ✓"
      >
        {isConnected ? "Create escrow & lock ETH" : "Connect wallet first"}
      </TxButton>

      {error && <p className="text-xs text-blood break-all">{error.message.split("\n")[0]}</p>}
      {isSuccess && (
        <p className="text-xs text-jade">
          Escrow created. Next: compute the commitment below, set it on the escrow, and share the salt with your agent.
        </p>
      )}
    </div>
  );
}
