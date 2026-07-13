"use client";

import { useMemo, useState } from "react";
import { keccak256, encodePacked, toHex } from "viem";
import { RefreshCw, Copy, Check } from "lucide-react";
import { Field } from "@/components/ui/Primitives";

function randomSalt(): `0x${string}` {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return toHex(bytes) as `0x${string}`;
}

const HEX32 = /^0x[0-9a-fA-F]{64}$/;

/**
 * Computes commitment = keccak256(abi.encodePacked(resultHash, salt))
 * entirely client-side. The client sets the commitment on-chain and
 * shares the salt with the agent off-chain.
 */
export function CommitmentHelper({
  onCommitment,
}: {
  onCommitment?: (commitment: `0x${string}`, salt: `0x${string}`) => void;
}) {
  const [resultHash, setResultHash] = useState("");
  const [salt, setSalt] = useState<`0x${string}`>(randomSalt);
  const [copied, setCopied] = useState<"salt" | "commitment" | null>(null);

  const commitment = useMemo(() => {
    if (!HEX32.test(resultHash) || !HEX32.test(salt)) return null;
    const c = keccak256(
      encodePacked(["bytes32", "bytes32"], [resultHash as `0x${string}`, salt])
    );
    onCommitment?.(c, salt);
    return c;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [resultHash, salt]);

  const copy = (text: string, which: "salt" | "commitment") => {
    navigator.clipboard.writeText(text);
    setCopied(which);
    setTimeout(() => setCopied(null), 1500);
  };

  return (
    <div className="ag-panel p-6 space-y-5">
      <div>
        <h3 className="font-display font-bold text-lg text-bone">Commitment helper</h3>
        <p className="text-xs text-text-muted mt-1 leading-relaxed">
          commitment = keccak256(resultHash ‖ salt). Computed in your browser — the
          salt never leaves this page until you share it with your agent.
        </p>
      </div>

      <Field
        label="Expected result hash (bytes32)"
        hint="keccak256 of the deliverable you expect. The agent must produce content matching this hash."
      >
        <input
          className="input font-mono"
          placeholder="0x…64 hex chars"
          value={resultHash}
          onChange={(e) => setResultHash(e.target.value.trim())}
        />
      </Field>

      <Field label="Salt (bytes32)" hint="Random blinding factor. Share with the agent off-chain after setting the commitment.">
        <div className="flex gap-2">
          <input
            className="input font-mono flex-1"
            value={salt}
            onChange={(e) => setSalt(e.target.value.trim() as `0x${string}`)}
          />
          <button type="button" className="btn-secondary px-3.5 !py-2" onClick={() => setSalt(randomSalt())} title="Regenerate">
            <RefreshCw size={15} />
          </button>
          <button type="button" className="btn-secondary px-3.5 !py-2" onClick={() => copy(salt, "salt")} title="Copy salt">
            {copied === "salt" ? <Check size={15} className="text-jade" /> : <Copy size={15} />}
          </button>
        </div>
      </Field>

      <div>
        <span className="label">Commitment</span>
        <div className="mt-2 flex items-center gap-2">
          <code className={`flex-1 block px-4 py-3 rounded-xl border text-xs font-mono break-all ${commitment ? "border-gold/40 bg-gold/5 text-gold-bright" : "border-border bg-raised text-text-muted"}`}>
            {commitment ?? "Enter a valid result hash to compute…"}
          </code>
          {commitment && (
            <button type="button" className="btn-secondary px-3.5 !py-2 shrink-0" onClick={() => copy(commitment, "commitment")}>
              {copied === "commitment" ? <Check size={15} className="text-jade" /> : <Copy size={15} />}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
