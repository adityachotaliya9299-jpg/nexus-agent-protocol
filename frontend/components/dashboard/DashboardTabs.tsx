"use client";

type Tab = "overview" | "tasks" | "reputation" | "memory" | "subscriptions";

const TABS: { id: Tab; label: string; icon: string }[] = [
  { id: "overview", label: "Overview", icon: "⬡" },
  { id: "tasks", label: "Tasks", icon: "◈" },
  { id: "reputation", label: "Reputation", icon: "◉" },
  { id: "memory", label: "Memory", icon: "⬟" },
  { id: "subscriptions", label: "Subscriptions", icon: "⬡" },
];

interface DashboardTabsProps {
  activeTab: Tab;
  onChange: (tab: string) => void;
}

export function DashboardTabs({ activeTab, onChange }: DashboardTabsProps) {
  return (
    <div className="flex gap-1 bg-[#0D1120] border border-[#1A2035] rounded-lg p-1 w-fit">
      {TABS.map((tab) => {
        const isActive = tab.id === activeTab;
        return (
          <button
            key={tab.id}
            onClick={() => onChange(tab.id)}
            className={`flex items-center gap-2 px-4 py-2 rounded-md text-sm font-medium transition-all duration-150 ${
              isActive
                ? "bg-[#0F1A2E] text-[#00E5FF] border border-cyan/20 shadow-[0_0_12px_rgba(0,229,255,0.08)]"
                : "text-[#8892B0] hover:text-[#F0F4FF] hover:bg-[#1A2035]/40"
            }`}
          >
            <span className={`text-xs ${isActive ? "text-cyan" : "text-[#4A5568]"}`}>
              {tab.icon}
            </span>
            <span className="font-display">{tab.label}</span>
          </button>
        );
      })}
    </div>
  );
}