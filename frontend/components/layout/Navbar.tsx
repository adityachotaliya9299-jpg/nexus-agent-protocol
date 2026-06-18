"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { Menu, X, Zap } from "lucide-react";

const NAV_LINKS = [
  { href: "/agents",        label: "Agents" },
  { href: "/tasks",         label: "Marketplace" },
  { href: "/subscriptions", label: "Subscriptions" },
  { href: "/dashboard",     label: "Dashboard" },
];

export function Navbar() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  return (
    <header className="sticky top-0 z-50 border-b border-[#1A2035] bg-[#080B12]/80 backdrop-blur-xl">
      <nav className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <Link href="/" className="flex items-center gap-2.5 group">
            <div className="w-8 h-8 rounded-md bg-cyan/10 border border-cyan/30 flex items-center justify-center group-hover:border-cyan/60 group-hover:bg-cyan/20 transition-all duration-200">
              <Zap className="w-4 h-4 text-cyan" />
            </div>
            <div className="flex flex-col leading-none">
              <span className="font-display font-bold text-sm text-[#F0F4FF] tracking-tight">NEXUS</span>
              <span className="font-mono text-[9px] text-[#8892B0] tracking-widest uppercase">Agent Protocol</span>
            </div>
          </Link>

          <div className="hidden md:flex items-center gap-1">
            {NAV_LINKS.map((link) => (
              <Link key={link.href} href={link.href}
                className={`px-4 py-2 rounded-md text-sm font-medium transition-all duration-200 ${
                  pathname?.startsWith(link.href)
                    ? "text-cyan bg-cyan/10 border border-cyan/20"
                    : "text-[#8892B0] hover:text-[#F0F4FF] hover:bg-[#1A2035]/50"
                }`}
              >{link.label}</Link>
            ))}
          </div>

          <div className="hidden md:flex items-center gap-3">
            <div className="flex items-center gap-2 px-3 py-1.5 rounded-md bg-[#0D1120] border border-[#1A2035]">
              <span className="w-2 h-2 rounded-full bg-emerald pulse-dot" />
              <span className="font-mono text-xs text-[#8892B0]">Sepolia</span>
            </div>
            <button className="btn-primary text-xs py-2 px-4">Connect Wallet</button>
          </div>

          <button
            className="md:hidden p-2 rounded-md text-[#8892B0] hover:text-[#F0F4FF] hover:bg-[#1A2035]/50 transition-colors"
            onClick={() => setOpen(!open)}
          >
            {open ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
          </button>
        </div>

        {open && (
          <div className="md:hidden border-t border-[#1A2035] py-4 space-y-1">
            {NAV_LINKS.map((link) => (
              <Link key={link.href} href={link.href} onClick={() => setOpen(false)}
                className={`block px-4 py-3 rounded-md text-sm font-medium transition-colors ${
                  pathname?.startsWith(link.href)
                    ? "text-cyan bg-cyan/10"
                    : "text-[#8892B0] hover:text-[#F0F4FF] hover:bg-[#1A2035]/50"
                }`}
              >{link.label}</Link>
            ))}
            <div className="pt-3 px-4">
              <button className="btn-primary w-full justify-center text-sm">Connect Wallet</button>
            </div>
          </div>
        )}
      </nav>
    </header>
  );
}