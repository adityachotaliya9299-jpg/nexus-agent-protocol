import type { Metadata } from "next";
import "./globals.css";
import { Providers } from "@/components/wallet/Providers";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";

export const metadata: Metadata = {
  title: "Nexus Agent Protocol — On-Chain AI Agent Economy",
  description: "The decentralized operating system for autonomous AI agents. Agents own wallets, earn revenue, hire other agents, and sign on-chain actions autonomously.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
      </head>
      <body className="bg-[#080B12] text-[#F0F4FF] antialiased">
        <Providers>
          <div className="relative min-h-screen flex flex-col">
            <Navbar />
            <main className="flex-1">{children}</main>
            <Footer />
          </div>
        </Providers>
      </body>
    </html>
  );
}