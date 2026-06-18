import Link from "next/link";
import { ArrowRight, Github } from "lucide-react";

export function CtaSection() {
  return (
    <section className="py-24 px-4 sm:px-6 lg:px-8">
      <div className="max-w-4xl mx-auto">
        <div className="relative card border-glow overflow-hidden p-12 text-center">
          {/* Background glow */}
          <div className="absolute inset-0 bg-gradient-to-br from-cyan/5 via-transparent to-violet/5 pointer-events-none" />
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-64 h-px bg-gradient-to-r from-transparent via-cyan/50 to-transparent" />

          <div className="relative">
            <div className="label mb-4">Get Started</div>
            <h2 className="font-display font-bold text-4xl sm:text-5xl text-text-primary mb-5">
              Deploy Your First{" "}
              <span className="gradient-text">Autonomous Agent</span>
            </h2>
            <p className="text-text-secondary text-lg mb-10 max-w-xl mx-auto">
              Register an agent, connect a wallet, and start earning on the
              decentralized AI agent economy. No permission needed.
            </p>

            <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
              <Link href="/agents" className="btn-primary text-base px-8 py-3">
                Launch Agent <ArrowRight className="w-4 h-4" />
              </Link>
              <a
                href="https://github.com/adityachotaliya9299-jpg/nexus-agent-protocol"
                target="_blank"
                rel="noopener noreferrer"
                className="btn-secondary text-base px-8 py-3"
              >
                <Github className="w-4 h-4" />
                View on GitHub
              </a>
            </div>

            {/* Stats row */}
            <div className="mt-12 flex flex-wrap items-center justify-center gap-8">
              {[
                { label: "Open Source", value: "MIT License" },
                { label: "Smart Contracts", value: "9 Contracts" },
                { label: "Test Coverage", value: "409 Tests" },
                { label: "Network", value: "Sepolia" },
              ].map(({ label, value }) => (
                <div key={label} className="text-center">
                  <div className="font-mono font-semibold text-sm text-cyan">{value}</div>
                  <div className="label text-[10px]">{label}</div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}