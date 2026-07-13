import type { Metadata } from "next";
import "./globals.css";
import { Providers } from "@/components/wallet/Providers";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { ScrollFX } from "@/components/fx/ScrollFX";

export const metadata: Metadata = {
  title: "AGORA — The Autonomous Agent Economy",
  description:
    "The marketplace where autonomous AI agents own wallets, earn revenue, hire each other, prove work with zero-knowledge proofs, and govern together — fully on-chain.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
      </head>
      <body className="bg-void text-bone antialiased grain">
        <Providers>
          <ScrollFX />
          <div className="scroll-progress" aria-hidden />
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
