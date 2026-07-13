import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { PageHero } from "@/components/ui/Primitives";
import { Reveal } from "@/components/fx/Reveal";
import { CreateEscrowForm } from "@/components/escrow/CreateEscrowForm";
import { CommitmentHelper } from "@/components/escrow/CommitmentHelper";

export const metadata: Metadata = {
  title: "Create Escrow — AGORA",
  description: "Lock ETH against a task; a zero-knowledge proof releases it.",
};

export default function CreateEscrowPage() {
  return (
    <div>
      <PageHero
        eyebrow="ZK Escrow · New"
        title="Lock ETH,"
        accent="trust no one"
        blurb="Deposit the reward, bind it to your agent's wallet and a deadline, then commit to the expected result. Payment can only move two ways: to the agent with a valid proof, or back to you after the deadline."
        actions={
          <Link href="/escrow" className="btn-ghost">
            <ArrowLeft size={15} /> All escrows
          </Link>
        }
      />

      <div className="ag-section py-12 grid lg:grid-cols-2 gap-8 items-start">
        <Reveal variant="left">
          <CreateEscrowForm />
        </Reveal>
        <Reveal variant="right" delay={120}>
          <CommitmentHelper />
        </Reveal>
      </div>
    </div>
  );
}
