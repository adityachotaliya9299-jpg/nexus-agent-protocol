"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ConnectButton } from "@/components/wallet/ConnectButton";

const NAV_LINKS = [
  { href: "/agents", label: "Agents" },
  { href: "/tasks", label: "Marketplace" },
  { href: "/subscriptions", label: "Subscriptions" },
  { href: "/dashboard", label: "Dashboard" },
  { href: '/dashboard/stake', label: 'Stake' }
];

export function Navbar() {
  const pathname = usePathname();

  return (
    <header className="sticky top-0 z-40 border-b border-[#1A2035] bg-[#080B12]/90 backdrop-blur-md">
      <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between gap-6">
        {/* Logo */}
        <Link href="/" className="flex items-center gap-2.5 flex-shrink-0">
          <div className="w-8 h-8 rounded-lg bg-cyan/10 border border-cyan/20 flex items-center justify-center">
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <path d="M8 1L14 4.5V11.5L8 15L2 11.5V4.5L8 1Z" stroke="#00E5FF" strokeWidth="1.5" strokeLinejoin="round" />
              <path d="M8 5L11 6.75V10.25L8 12L5 10.25V6.75L8 5Z" fill="#00E5FF" fillOpacity="0.3" stroke="#00E5FF" strokeWidth="1" strokeLinejoin="round" />
            </svg>
          </div>
          <div>
            <div className="font-display font-bold text-sm text-[#F0F4FF] leading-none">NEXUS</div>
            <div className="font-mono text-[9px] text-[#4A5568] leading-none tracking-widest uppercase">Agent Protocol</div>
          </div>
        </Link>

        {/* Nav links */}
        <nav className="hidden md:flex items-center gap-1">
          {NAV_LINKS.map((link) => {
            const isActive = pathname === link.href || pathname.startsWith(link.href + "/");
            return (
              <Link
                key={link.href}
                href={link.href}
                className={`px-4 py-2 rounded-md text-sm font-medium transition-all duration-150 ${
                  isActive
                    ? "bg-cyan/10 text-cyan border border-cyan/15"
                    : "text-[#8892B0] hover:text-[#F0F4FF] hover:bg-[#1A2035]/50"
                }`}
              >
                {link.label}
              </Link>
            );
          })}
        </nav>

        {/* Wallet */}
        <ConnectButton />
      </div>
    </header>
  );
}