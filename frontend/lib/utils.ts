import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function shortAddress(address: string, chars = 4): string {
  if (!address) return "";
  return `${address.slice(0, 2 + chars)}...${address.slice(-chars)}`;
}

export function formatEth(wei: bigint, decimals = 4): string {
  const eth = Number(wei) / 1e18;
  return eth.toFixed(decimals).replace(/\.?0+$/, "");
}

export function formatReputation(score: number): string {
  return (score / 100).toFixed(1) + "%";
}

export function repToPercent(score: number): number {
  return Math.round(score / 100);
}

export function repLabel(score: number): string {
  if (score >= 9000) return "Elite";
  if (score >= 7500) return "Expert";
  if (score >= 6000) return "Advanced";
  if (score >= 4500) return "Established";
  if (score >= 3000) return "Developing";
  return "New";
}

export function repColor(score: number): string {
  if (score >= 9000) return "#F59E0B";
  if (score >= 7500) return "#00E5FF";
  if (score >= 6000) return "#8B5CF6";
  if (score >= 4500) return "#10B981";
  if (score >= 3000) return "#6366F1";
  return "#8892B0";
}



export function repBarColor(score: number): string {
  if (score >= 8000) return "bg-emerald";
  if (score >= 6000) return "bg-cyan";
  if (score >= 4000) return "bg-amber";
  return "bg-rose";
}

export function timeAgo(timestamp: number): string {
  const now = Date.now() / 1000;
  const diff = now - timestamp;
  if (diff < 60)      return "just now";
  if (diff < 3600)    return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400)   return `${Math.floor(diff / 3600)}h ago`;
  if (diff < 2592000) return `${Math.floor(diff / 86400)}d ago`;
  return `${Math.floor(diff / 2592000)}mo ago`;
}

export const CATEGORY_LABELS: Record<number, string> = {
  0: "General", 1: "Code", 2: "Research", 3: "Trading", 4: "Creative", 5: "Orchestrator",
};

export const CATEGORY_COLORS: Record<number, string> = {
  0: "badge-inactive",
  1: "badge-violet",
  2: "badge-active",
  3: "badge-pending",
  4: "badge-violet",
  5: "badge bg-cyan/10 text-cyan border border-cyan/20",
};