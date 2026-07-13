"use client";

import { useRef, useState } from "react";
import { keccak256 } from "viem";
import { useAccount } from "wagmi";
import { FileUp } from "lucide-react";
import { Field } from "@/components/ui/Primitives";
import { TxButton } from "@/components/wallet/TxButton";
import { useAnchorResult } from "@/lib/hooks/useResultStorage";

const HEX32 = /^0x[0-9a-fA-F]{64}$/;
const ARWEAVE_ID = /^[A-Za-z0-9_-]{43}$/;

export function AnchorResultForm() {
  const { isConnected } = useAccount();
  const { anchorResult, isPending, isConfirming, isSuccess, error } = useAnchorResult();
  const fileRef = useRef<HTMLInputElement>(null);

  const [taskId, setTaskId] = useState("");
  const [agentId, setAgentId] = useState("");
  const [arweaveTxId, setArweaveTxId] = useState("");
  const [contentHash, setContentHash] = useState("");
  const [contentSize, setContentSize] = useState("");
  const [contentType, setContentType] = useState("application/json");
  const [hashedName, setHashedName] = useState<string | null>(null);

  const valid =
    HEX32.test(taskId) &&
    Number(agentId) > 0 &&
    ARWEAVE_ID.test(arweaveTxId) &&
    HEX32.test(contentHash) &&
    Number(contentSize) > 0;

  const hashFile = async (file: File) => {
    const buf = new Uint8Array(await file.arrayBuffer());
    setContentHash(keccak256(buf));
    setContentSize(String(buf.byteLength));
    setContentType(file.type || "application/octet-stream");
    setHashedName(file.name);
  };

  return (
    <div className="ag-panel p-6 space-y-5">
      <div>
        <h3 className="font-display font-bold text-lg text-bone">Anchor a result</h3>
        <p className="text-xs text-text-muted mt-1 leading-relaxed">
          Upload the deliverable to Arweave first (pay once, stored forever). Then anchor
          the 43-char TX ID + keccak256 of the exact bytes here.
        </p>
      </div>

      <div className="grid sm:grid-cols-2 gap-5">
        <Field label="Task ID (bytes32)">
          <input className="input font-mono" placeholder="0x…" value={taskId} onChange={(e) => setTaskId(e.target.value.trim())} />
        </Field>
        <Field label="Your agent ID">
          <input className="input" type="number" min="1" placeholder="#" value={agentId} onChange={(e) => setAgentId(e.target.value)} />
        </Field>
      </div>

      <Field label="Arweave TX ID" hint="Exactly 43 base64url characters — from your Arweave upload receipt.">
        <input className="input font-mono" placeholder="e.g. dQ3…43 chars" value={arweaveTxId} onChange={(e) => setArweaveTxId(e.target.value.trim())} />
      </Field>

      <div className="rounded-2xl border border-dashed border-gold/30 bg-gold/5 p-5 text-center">
        <input
          ref={fileRef}
          type="file"
          className="hidden"
          onChange={(e) => e.target.files?.[0] && hashFile(e.target.files[0])}
        />
        <button type="button" className="btn-secondary mx-auto" onClick={() => fileRef.current?.click()}>
          <FileUp size={15} /> {hashedName ? `Re-hash a file` : "Hash the deliverable locally"}
        </button>
        <p className="text-[11px] text-text-muted mt-2">
          {hashedName
            ? `Hashed "${hashedName}" — hash, size, and type filled below. The file never leaves your machine.`
            : "Pick the exact file you uploaded to Arweave; keccak256 is computed in-browser."}
        </p>
      </div>

      <div className="grid sm:grid-cols-3 gap-5">
        <Field label="Content hash (bytes32)">
          <input className="input font-mono" placeholder="0x…" value={contentHash} onChange={(e) => setContentHash(e.target.value.trim())} />
        </Field>
        <Field label="Size (bytes)">
          <input className="input" type="number" min="1" value={contentSize} onChange={(e) => setContentSize(e.target.value)} />
        </Field>
        <Field label="Content type">
          <input className="input" value={contentType} onChange={(e) => setContentType(e.target.value)} />
        </Field>
      </div>

      <TxButton
        onClick={() => anchorResult(taskId as `0x${string}`, Number(agentId), arweaveTxId, contentHash as `0x${string}`, Number(contentSize), contentType)}
        disabled={!isConnected || !valid}
        isPending={isPending}
        isConfirming={isConfirming}
        isSuccess={isSuccess}
        className="btn-primary w-full"
        successText="Anchored forever ✓"
      >
        {isConnected ? "Anchor on-chain" : "Connect wallet first"}
      </TxButton>

      {error && <p className="text-xs text-blood break-all">{error.message.split("\n")[0]}</p>}
    </div>
  );
}
