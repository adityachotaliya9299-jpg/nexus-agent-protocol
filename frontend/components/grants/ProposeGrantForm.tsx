"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { Field } from "@/components/ui/Primitives";
import { TxButton } from "@/components/wallet/TxButton";
import { useProposeGrant, GRANT_TYPES } from "@/lib/hooks/useCommunityGrants";

const ADDR = /^0x[0-9a-fA-F]{40}$/;

export function ProposeGrantForm() {
  const { isConnected } = useAccount();
  const { proposeGrant, isPending, isConfirming, isSuccess, error } = useProposeGrant();

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [recipient, setRecipient] = useState("");
  const [amount, setAmount] = useState("");
  const [grantType, setGrantType] = useState(0);
  const [agentId, setAgentId] = useState("");

  const valid =
    title.length > 2 && description.length > 10 && ADDR.test(recipient) && parseFloat(amount || "0") > 0 && Number(agentId) > 0;

  return (
    <div className="ag-panel p-6 space-y-5">
      <div>
        <h3 className="font-display font-bold text-lg text-bone">Propose a grant</h3>
        <p className="text-xs text-text-muted mt-1">
          Any registered agent can propose. Votes are weighted by reputation score.
        </p>
      </div>

      <Field label="Title">
        <input className="input" placeholder="Fund the thing that matters" value={title} onChange={(e) => setTitle(e.target.value)} />
      </Field>

      <Field label="Description">
        <textarea className="input min-h-[110px] resize-y" placeholder="What will this grant fund, and why should agents vote for it?" value={description} onChange={(e) => setDescription(e.target.value)} />
      </Field>

      <div className="grid sm:grid-cols-2 gap-5">
        <Field label="Recipient address">
          <input className="input font-mono" placeholder="0x…" value={recipient} onChange={(e) => setRecipient(e.target.value.trim())} />
        </Field>
        <Field label="Amount (ETH)">
          <input className="input" type="number" min="0" step="0.001" placeholder="0.5" value={amount} onChange={(e) => setAmount(e.target.value)} />
        </Field>
      </div>

      <div className="grid sm:grid-cols-2 gap-5">
        <Field label="Grant type">
          <div className="flex flex-wrap gap-2">
            {GRANT_TYPES.map((t, i) => (
              <button
                key={t}
                type="button"
                onClick={() => setGrantType(i)}
                className={`px-3 py-1.5 rounded-full text-[11px] font-mono uppercase tracking-wider border transition-all ${
                  grantType === i ? "bg-gold/15 border-gold/50 text-gold" : "border-border text-text-muted hover:text-bone"
                }`}
              >
                {t}
              </button>
            ))}
          </div>
        </Field>
        <Field label="Your agent ID (proposer)">
          <input className="input" type="number" min="1" placeholder="#" value={agentId} onChange={(e) => setAgentId(e.target.value)} />
        </Field>
      </div>

      <TxButton
        onClick={() => proposeGrant(title, description, recipient as `0x${string}`, amount, grantType, Number(agentId))}
        disabled={!isConnected || !valid}
        isPending={isPending}
        isConfirming={isConfirming}
        isSuccess={isSuccess}
        className="btn-primary w-full"
        successText="Proposed — voting is open ✓"
      >
        {isConnected ? "Submit proposal" : "Connect wallet first"}
      </TxButton>

      {error && <p className="text-xs text-blood break-all">{error.message.split("\n")[0]}</p>}
    </div>
  );
}
