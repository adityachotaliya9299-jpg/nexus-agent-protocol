"use client";

import Link from "next/link";
import { useState } from "react";
import { usePathname } from "next/navigation";
import { ChevronDown, Menu, X, ShieldAlert } from "lucide-react";
import { useAccount, useReadContract } from "wagmi";
import { ConnectButton } from "@/components/wallet/ConnectButton";
import { Logo } from "@/components/brand/Logo";
import { CONTRACTS, PROTOCOL_GUARD_ABI } from "@/lib/contracts";

const PRIMARY_LINKS = [
  { href: "/agents", label: "Agents" },
  { href: "/tasks", label: "Marketplace" },
  { href: "/escrow", label: "Escrow" },
  { href: "/workflows", label: "Workflows" },
];

const GOVERN_LINKS = [
  { href: "/dao", label: "Agent DAOs", hint: "Teams that split revenue trustlessly" },
  { href: "/grants", label: "Community Grants", hint: "Treasury funding, voted on-chain" },
];

const MORE_LINKS = [
  { href: "/discover", label: "Discover", hint: "Search & leaderboards" },
  { href: "/subscriptions", label: "Subscriptions", hint: "Recurring agent access" },
  { href: "/results", label: "Results", hint: "Arweave-anchored proofs of work" },
  { href: "/dashboard/subtasks", label: "Sub-tasks", hint: "Agents hiring agents" },
  { href: "/dashboard/stake", label: "Stake", hint: "Back agents with ETH" },
  { href: "/admin/guard", label: "Protocol Guard", hint: "Circuit breaker (owner)" },
];

function Dropdown({
  label,
  links,
  active,
}: {
  label: string;
  links: { href: string; label: string; hint: string }[];
  active: boolean;
}) {
  return (
    <div className="relative group">
      <button
        className={`flex items-center gap-1 px-4 py-2 rounded-full text-sm font-medium transition-all duration-200 ${
          active ? "text-gold" : "text-text-secondary hover:text-bone"
        }`}
      >
        {label}
        <ChevronDown size={13} className="transition-transform duration-200 group-hover:rotate-180" />
      </button>
      <div className="absolute left-0 top-full pt-2 opacity-0 invisible translate-y-2 group-hover:opacity-100 group-hover:visible group-hover:translate-y-0 transition-all duration-200 z-50">
        <div className="w-72 ag-panel p-2 shadow-[0_24px_60px_-12px_rgba(0,0,0,0.7)]">
          {links.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className="block px-4 py-3 rounded-2xl hover:bg-raised transition-colors"
            >
              <div className="text-sm font-semibold text-bone">{l.label}</div>
              <div className="text-xs text-text-muted mt-0.5">{l.hint}</div>
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}

export function Navbar() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  const { address } = useAccount();
  const { data: guardOwner } = useReadContract({
    address: CONTRACTS.ProtocolGuard,
    abi: PROTOCOL_GUARD_ABI,
    functionName: "owner",
    query: { enabled: !!address },
  });
  const isOwner = !!address && !!guardOwner && address.toLowerCase() === (guardOwner as string).toLowerCase();

  const isActive = (href: string) => pathname === href || pathname.startsWith(href + "/");

  return (
    <header className="sticky top-0 z-40 border-b border-border/70 bg-void/85 backdrop-blur-xl">
      <div className="max-w-7xl mx-auto px-6 h-[68px] flex items-center justify-between gap-6">
        <Link href="/" className="flex-shrink-0" onClick={() => setOpen(false)}>
          <Logo />
        </Link>

        <nav className="hidden lg:flex items-center gap-0.5">
          {PRIMARY_LINKS.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className={`px-4 py-2 rounded-full text-sm font-medium transition-all duration-200 ${
                isActive(link.href)
                  ? "bg-gold/10 text-gold border border-gold/20"
                  : "text-text-secondary hover:text-bone hover:bg-raised"
              }`}
            >
              {link.label}
            </Link>
          ))}
          <Dropdown label="Govern" links={GOVERN_LINKS} active={isActive("/dao") || isActive("/grants")} />
          <Dropdown label="More" links={MORE_LINKS} active={MORE_LINKS.some((l) => isActive(l.href))} />
          <Link
            href="/dashboard"
            className={`px-4 py-2 rounded-full text-sm font-medium transition-all duration-200 ${
              isActive("/dashboard")
                ? "bg-gold/10 text-gold border border-gold/20"
                : "text-text-secondary hover:text-bone hover:bg-raised"
            }`}
          >
            Dashboard
          </Link>
          {isOwner && (
            <Link
              href="/admin/guard"
              className={`flex items-center gap-1.5 px-4 py-2 rounded-full text-sm font-medium transition-all duration-200 ${
                isActive("/admin")
                  ? "bg-ember/10 text-ember border border-ember/25"
                  : "text-ember/80 hover:text-ember hover:bg-ember/5"
              }`}
            >
              <ShieldAlert size={14} />
              Admin
            </Link>
          )}
        </nav>

        <div className="flex items-center gap-3">
          <ConnectButton />
          <button
            className="lg:hidden text-text-secondary hover:text-bone p-2"
            onClick={() => setOpen(!open)}
            aria-label="Toggle menu"
          >
            {open ? <X size={22} /> : <Menu size={22} />}
          </button>
        </div>
      </div>

      {/* mobile menu */}
      {open && (
        <div className="lg:hidden border-t border-border bg-void/95 backdrop-blur-xl px-6 py-4 space-y-1 max-h-[75vh] overflow-y-auto">
          {[...PRIMARY_LINKS, ...GOVERN_LINKS, ...MORE_LINKS, { href: "/dashboard", label: "Dashboard" }].map(
            (link) => (
              <Link
                key={link.href}
                href={link.href}
                onClick={() => setOpen(false)}
                className={`block px-4 py-3 rounded-xl text-sm font-medium ${
                  isActive(link.href) ? "bg-gold/10 text-gold" : "text-text-secondary hover:bg-raised hover:text-bone"
                }`}
              >
                {link.label}
              </Link>
            )
          )}
        </div>
      )}
    </header>
  );
}
