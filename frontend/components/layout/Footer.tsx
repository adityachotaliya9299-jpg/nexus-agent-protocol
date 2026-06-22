import Link from "next/link";
import { Zap, Code2 , ExternalLink } from "lucide-react";

const LINKS = {
  Protocol: [
    { label: "Agent Registry",  href: "/agents" },
    { label: "Task Marketplace", href: "/tasks" },
    { label: "Subscriptions",   href: "/subscriptions" },
    { label: "Dashboard",       href: "/dashboard" },
  ],
  Developers: [
    { label: "GitHub",  href: "https://github.com/adityachotaliya9299-jpg/nexus-agent-protocol", external: true },
    { label: "Contracts", href: "/contracts" },
  ],
  Resources: [
    { label: "Portfolio", href: "https://adityachotaliya.vercel.app", external: true },
    { label: "Roadmap",   href: "/roadmap" },
  ],
};

export function Footer() {
  return (
    <footer className="border-t border-[#1A2035] bg-[#0D1120]/50 mt-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-12">
          <div>
            <Link href="/" className="flex items-center gap-2.5 mb-4">
              <div className="w-8 h-8 rounded-md bg-cyan/10 border border-cyan/30 flex items-center justify-center">
                <Zap className="w-4 h-4 text-cyan" />
              </div>
              <span className="font-display font-bold text-[#F0F4FF]">Nexus Protocol</span>
            </Link>
            <p className="text-sm text-[#8892B0] leading-relaxed mb-6">
              The on-chain operating system for autonomous AI agents. Agents own wallets,
              earn revenue, and interact permissionlessly.
            </p>
            <a
              href="https://github.com/adityachotaliya9299-jpg/nexus-agent-protocol"
              target="_blank" rel="noopener noreferrer"
              className="p-2 inline-flex rounded-md bg-[#1A2035]/50 text-[#8892B0] hover:text-[#F0F4FF] hover:bg-[#1A2035] transition-colors"
            >
              <Code2  className="w-4 h-4" />
            </a>
          </div>

          {Object.entries(LINKS).map(([group, links]) => (
            <div key={group}>
              <h3 className="label mb-4">{group}</h3>
              <ul className="space-y-3">
                {links.map((link) => (
                  <li key={link.label}>
                    {"external" in link && link.external ? (
                      <a href={link.href} target="_blank" rel="noopener noreferrer"
                        className="flex items-center gap-1.5 text-sm text-[#8892B0] hover:text-[#F0F4FF] transition-colors">
                        {link.label} <ExternalLink className="w-3 h-3" />
                      </a>
                    ) : (
                      <Link href={link.href} className="text-sm text-[#8892B0] hover:text-[#F0F4FF] transition-colors">
                        {link.label}
                      </Link>
                    )}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <div className="mt-12 pt-6 border-t border-[#1A2035] flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-xs text-[#4A5568] font-mono">
            © 2026 Nexus Agent Protocol. Built by{" "}
            <a href="https://adityachotaliya.vercel.app" target="_blank" rel="noopener noreferrer"
              className="text-cyan hover:text-cyan/80 transition-colors">
              Aditya Chotaliya
            </a>
          </p>
          <div className="flex items-center gap-2">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald" />
            <span className="text-xs font-mono text-[#8892B0]">All systems operational</span>
          </div>
        </div>
      </div>
    </footer>
  );
}