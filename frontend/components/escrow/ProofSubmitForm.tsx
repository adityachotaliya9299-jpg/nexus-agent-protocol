"use client";

import { useState } from "react";
import { useReleaseWithProof, type Groth16Proof } from "@/lib/hooks/useZKEscrow";
import { TxButton } from "@/components/wallet/TxButton";
import { Field } from "@/components/ui/Primitives";

const HEX32 = /^0x[0-9a-fA-F]{64}$/;

/**
 * Paste the proof JSON produced by `scripts/zk/generate-proof.js`
 * (snarkjs calldata shape) and release the escrow on-chain.
 */
export function ProofSubmitForm({ escrowId }: { escrowId: `0x${string}` }) {
  const { releaseWithProof, isPending, isConfirming, isSuccess, error } = useReleaseWithProof();
  const [resultHash, setResultHash] = useState("");
  const [salt, setSalt] = useState("");
  const [proofJson, setProofJson] = useState("");
  const [parseError, setParseError] = useState<string | null>(null);

  const parseProof = (): Groth16Proof | null => {
    try {
      const raw = JSON.parse(proofJson);
      // Accepts { pA, pB, pC, pubSignals } or snarkjs { pi_a, pi_b, pi_c, publicSignals }
      const pA = (raw.pA ?? raw.pi_a)?.slice(0, 2).map(BigInt);
      const pBraw = raw.pB ?? raw.pi_b;
      const pB = pBraw?.slice(0, 2).map((pair: string[]) => pair.slice(0, 2).map(BigInt));
      const pC = (raw.pC ?? raw.pi_c)?.slice(0, 2).map(BigInt);
      const pub = (raw.pubSignals ?? raw.publicSignals)?.slice(0, 2).map(BigInt);
      if (!pA || !pB || !pC || !pub || pA.length !== 2 || pB.length !== 2 || pC.length !== 2 || pub.length !== 2) {
        throw new Error("missing fields");
      }
      return { pA: pA as [bigint, bigint], pB: pB as [[bigint, bigint], [bigint, bigint]], pC: pC as [bigint, bigint], pubSignals: pub as [bigint, bigint] };
    } catch {
      setParseError("Could not parse proof JSON — expected { pA, pB, pC, pubSignals } or snarkjs output.");
      return null;
    }
  };

  const submit = () => {
    setParseError(null);
    const proof = parseProof();
    if (!proof) return;
    releaseWithProof(escrowId, resultHash as `0x${string}`, salt as `0x${string}`, proof);
  };

  const valid = HEX32.test(resultHash) && HEX32.test(salt) && proofJson.trim().length > 0;

  return (
    <div className="ag-panel p-6 space-y-5">
      <div>
        <h3 className="font-display font-bold text-lg text-bone">Release with ZK proof</h3>
        <p className="text-xs text-text-muted mt-1 leading-relaxed">
          Agent side: paste the output of <code className="text-gold">scripts/zk/generate-proof.js</code>.
          A valid proof pays out instantly — no client approval needed.
        </p>
      </div>

      <div className="grid sm:grid-cols-2 gap-5">
        <Field label="Result hash (bytes32)">
          <input className="input font-mono" placeholder="0x…" value={resultHash} onChange={(e) => setResultHash(e.target.value.trim())} />
        </Field>
        <Field label="Salt (bytes32)" hint="Shared with you by the client.">
          <input className="input font-mono" placeholder="0x…" value={salt} onChange={(e) => setSalt(e.target.value.trim())} />
        </Field>
      </div>

      <Field label="Groth16 proof JSON">
        <textarea
          className="input font-mono min-h-[130px] resize-y"
          placeholder='{ "pA": [..], "pB": [[..],[..]], "pC": [..], "pubSignals": [..] }'
          value={proofJson}
          onChange={(e) => setProofJson(e.target.value)}
        />
      </Field>

      <TxButton
        onClick={submit}
        disabled={!valid}
        isPending={isPending}
        isConfirming={isConfirming}
        isSuccess={isSuccess}
        className="btn-primary w-full"
        successText="Payment released ✓"
      >
        Verify proof & release payment
      </TxButton>

      {parseError && <p className="text-xs text-blood">{parseError}</p>}
      {error && <p className="text-xs text-blood break-all">{error.message.split("\n")[0]}</p>}
    </div>
  );
}
