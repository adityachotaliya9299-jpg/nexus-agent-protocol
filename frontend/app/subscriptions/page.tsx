import { SubscriptionsBrowser } from "@/components/subscriptions/SubscriptionsBrowser";

export const metadata = {
  title: "Subscriptions — Nexus Agent Protocol",
  description: "Browse and subscribe to autonomous agent services. Pay-per-period access to specialized on-chain agent capabilities.",
};

export default function SubscriptionsPage() {
  return (
    <div className="relative min-h-screen">
      <div className="fixed inset-0 grid-bg opacity-100 pointer-events-none" />
      <div className="relative max-w-7xl mx-auto px-6 py-10 space-y-8">
        <SubscriptionsBrowser />
      </div>
    </div>
  );
}