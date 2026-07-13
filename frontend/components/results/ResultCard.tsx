"use client";

import { useState } from "react";
import { keccak256 } from "viem";
import { ExternalLink, ShieldCheck, Anchor } from "lucide-react";
import { Pill, InfoRow } from "@/components/ui/Primitives";
import { TxButton } from "@/components/wallet/TxButton";
import { useStoredResult, useVerifyResult } from "@/lib/hooks/useResultStorage";
import { shortenAddr } from "@/lib/contracts";

const ZERO32 = "0x0000000000000000000000000000000000000000000000000000000000000000";

export function VerificationBadge({ verified }: { verified: boolean }) {
  return verified ? (
    <Pill tone="jade"><ShieldCheck size={12} /> VERIFIED</Pill>
  ) : (
    <Pill tone="gold"><Anchor size={12} /> ANCHORED</Pill>
  );
}

/**
 * Card for one anchored result. "Verify" fetches the content from the
 * Arweave gateway, keccak-hashes it in the browser, and calls
 * verifyResult() on-chain if the hash matches.
 */
export function ResultCard({ taskId }: { taskId: `0x${string}` }) {
  const { data, refetch } = useStoredResult(taskId);
  const { verifyResult, isPending, isConfirming, isSuccess } = useVerifyResult();
  const [checking, setChecking] = useState(false);
  const [checkError, setCheckError] = useState<string | null>(null);

  const r = data as
    | {
        taskId: `0x${string}`;
        agentId: bigint;
        arweaveTxId: string;
        contentHash: `0x${string}`;
        contentSize: bigint;
        contentType: string;
        storedAt: bigint;
        verified: boolean;
      }
    | undefined;

  if (!r || r.taskId === ZERO32) return null;

  const verify = async () => {
    setChecking(true);
    setCheckError(null);
    try {
      const res = await fetch(`https://arweave.net/${r.arweaveTxId}`);
      if (!res.ok) throw new Error(`Arweave gateway returned ${res.status}`);
      const buf = new Uint8Array(await res.arrayBuffer());
      const hash = keccak256(buf);
      if (hash.toLowerCase() !== r.contentHash.toLowerCase()) {
        throw new Error("Hash mismatch — fetched content does not match the anchored hash.");
      }
      verifyResult(taskId, hash);
    } catch (err) {
      setCheckError(err instanceof Error ? err.message : "Verification failed");
    } finally {
      setChecking(false);
    }
  };

  return (
    <div className="card-hover p-6">
      <div className="flex items-start justify-between gap-3">
        <span className="font-mono text-xs text-text-muted">{shortenAddr(r.taskId)}</span>
        <VerificationBadge verified={r.verified || isSuccess} />
      </div>

      <div className="mt-4">
        <InfoRow label="Agent">#{r.agentId.toString()}</InfoRow>
        <InfoRow label="Type">{r.contentType || "unknown"}</InfoRow>
        <InfoRow label="Size">{Number(r.contentSize).toLocaleString()} bytes</InfoRow>
        <InfoRow label="Anchored">{new Date(Number(r.storedAt) * 1000).toLocaleDateString()}</InfoRow>
        <InfoRow label="Content hash"><span className="font-mono text-xs">{shortenAddr(r.contentHash)}</span></InfoRow>
      </div>

      <div className="mt-5 flex flex-wrap gap-3">
        <a
          href={`https://arweave.net/${r.arweaveTxId}`}
          target="_blank"
          rel="noopener noreferrer"
          className="btn-secondary text-xs !px-4 !py-2"
        >
          <ExternalLink size={13} /> arweave.net/{r.arweaveTxId.slice(0, 8)}…
        </a>
        {!r.verified && !isSuccess && (
          <TxButton
            onClick={verify}
            isPending={checking || isPending}
            isConfirming={isConfirming}
            isSuccess={isSuccess}
            className="btn-primary text-xs !px-4 !py-2"
            pendingText={checking ? "Fetching & hashing…" : "Sign in wallet..."}
            successText="Verified ✓"
          >
            <ShieldCheck size={13} /> Fetch & verify
          </TxButton>
        )}
        {isSuccess && (
          <button className="btn-ghost text-xs" onClick={() => refetch()}>Refresh</button>
        )}
      </div>
      {checkError && <p className="text-xs text-blood mt-3">{checkError}</p>}
    </div>
  );
}
