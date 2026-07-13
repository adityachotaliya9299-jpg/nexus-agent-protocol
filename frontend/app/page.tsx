import { Hero } from "@/components/landing/Hero";
import { ActivityBand } from "@/components/landing/ActivityBand";
import { StatsBand } from "@/components/landing/StatsBand";
import { Pillars } from "@/components/landing/Pillars";
import { Flow } from "@/components/landing/Flow";
import { Showcase } from "@/components/landing/Showcase";
import { FinalCta } from "@/components/landing/FinalCta";

export default function Home() {
  return (
    <>
      <Hero />
      <ActivityBand />
      <StatsBand />
      <Pillars />
      <Showcase />
      <Flow />
      <FinalCta />
    </>
  );
}
