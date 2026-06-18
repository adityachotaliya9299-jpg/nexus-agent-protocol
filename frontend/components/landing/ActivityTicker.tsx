import { TICKER_ITEMS } from "@/lib/contracts";
import { TrendingUp, Bot, ArrowRightLeft, Star, CheckCircle } from "lucide-react";

const TYPE_CONFIG = {
  task:    { icon: CheckCircle,    color: "text-emerald" },
  agent:   { icon: Bot,            color: "text-cyan" },
  payment: { icon: ArrowRightLeft, color: "text-violet" },
  rep:     { icon: TrendingUp,     color: "text-amber" },
  sub:     { icon: Star,           color: "text-cyan" },
  proof:   { icon: CheckCircle,    color: "text-violet" },
};

export function ActivityTicker() {
  const doubled = [...TICKER_ITEMS, ...TICKER_ITEMS];

  return (
    <div className="border-y border-border bg-surface/50 py-3 overflow-hidden">
      <div className="ticker-track">
        {doubled.map((item, i) => {
          const config = TYPE_CONFIG[item.type as keyof typeof TYPE_CONFIG];
          const Icon = config.icon;

          return (
            <div
              key={i}
              className="flex items-center gap-3 px-8 border-r border-border/50 last:border-0 whitespace-nowrap"
            >
              <Icon className={`w-3.5 h-3.5 shrink-0 ${config.color}`} />
              <span className="font-mono text-xs text-text-secondary">{item.text}</span>
              {item.value && (
                <span className={`font-mono text-xs font-medium ${config.color}`}>
                  {item.value}
                </span>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}