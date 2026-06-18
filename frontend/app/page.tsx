import { HeroSection } from "@/components/landing/HeroSection";
import { StatsBar } from "@/components/landing/StatsBar";
import { ActivityTicker } from "@/components/landing/ActivityTicker";
import { FeaturesSection } from "@/components/landing/FeaturesSection";
import { HowItWorks } from "@/components/landing/HowItWorks";
import { AgentShowcase } from "@/components/landing/AgentShowcase";
import { CtaSection } from "@/components/landing/CtaSection";

export default function HomePage() {
  return (
    <div className="relative">
      {/* Grid background */}
      <div className="fixed inset-0 grid-bg opacity-100 pointer-events-none" />

      {/* Hero glow */}
      <div className="absolute inset-x-0 top-0 h-[600px] hero-glow pointer-events-none" />

      <HeroSection />
      <ActivityTicker />
      <StatsBar />
      <FeaturesSection />
      <HowItWorks />
      <AgentShowcase />
      <CtaSection />
    </div>
  );
}