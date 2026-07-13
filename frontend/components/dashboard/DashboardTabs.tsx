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
    <div className="flex gap-1 bg-[#14110D] border border-[#2A241B] rounded-lg p-1 w-fit">
      {TABS.map((tab) => {
        const isActive = tab.id === activeTab;
        return (
          <button
            key={tab.id}
            onClick={() => onChange(tab.id)}
            className={`flex items-center gap-2 px-4 py-2 rounded-md text-sm font-medium transition-all duration-150 ${
              isActive
                ? "bg-[#0F1A2E] text-[#F2A93B] border border-cyan/20 shadow-[0_0_12px_rgba(242,169,59,0.08)]"
                : "text-[#A89F8D] hover:text-[#F4EFE6] hover:bg-[#2A241B]/40"
            }`}
          >
            <span className={`text-xs ${isActive ? "text-cyan" : "text-[#6B6355]"}`}>
              {tab.icon}
            </span>
            <span className="font-display">{tab.label}</span>
          </button>
        );
      })}
    </div>
  );
}