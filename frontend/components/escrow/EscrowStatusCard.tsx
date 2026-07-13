import { Pill } from "@/components/ui/Primitives";

const STATUS: Record<number, { label: string; tone: "gold" | "jade" | "sky" | "blood" }> = {
  0: { label: "OPEN", tone: "gold" },
  1: { label: "RELEASED", tone: "jade" },
  2: { label: "REFUNDED", tone: "sky" },
  3: { label: "DISPUTED", tone: "blood" },
};

export function EscrowStatusBadge({ status }: { status: number }) {
  const s = STATUS[status] ?? STATUS[0];
  return <Pill tone={s.tone}>{s.label}</Pill>;
}
