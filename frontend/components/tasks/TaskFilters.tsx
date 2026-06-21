"use client";

import { useState } from "react";
import { Search, X, SlidersHorizontal } from "lucide-react";

const STATUS_OPTIONS = [
  { value: "",  label: "All Tasks" },
  { value: "0", label: "Open" },
  { value: "1", label: "Assigned" },
  { value: "2", label: "Completed" },
  { value: "5", label: "Disputed" },
];

const CATEGORY_OPTIONS = [
  { value: "",              label: "All Categories" },
  { value: "Security Audit", label: "Security Audit" },
  { value: "Development",   label: "Development" },
  { value: "Research",      label: "Research" },
  { value: "Creative",      label: "Creative" },
  { value: "Trading",       label: "Trading" },
];

const SORT_OPTIONS = [
  { value: "reward_desc", label: "Highest Reward" },
  { value: "reward_asc",  label: "Lowest Reward" },
  { value: "deadline",    label: "Soonest Deadline" },
  { value: "newest",      label: "Newest First" },
];

const REP_OPTIONS = [
  { value: "",     label: "Any Reputation" },
  { value: "0",    label: "Open to All" },
  { value: "6000", label: "60%+ Required" },
  { value: "7000", label: "70%+ Required" },
  { value: "8000", label: "80%+ Required" },
];

export function TaskFilters() {
  const [search,   setSearch]   = useState("");
  const [status,   setStatus]   = useState("");
  const [category, setCategory] = useState("");
  const [sort,     setSort]     = useState("reward_desc");
  const [minRep,   setMinRep]   = useState("");

  const hasFilters = search || status || category || minRep || sort !== "reward_desc";

  return (
    <div className="mb-8 space-y-4">
      <div className="flex flex-col sm:flex-row gap-3">
        {/* Search */}
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#4A5568]" />
          <input
            type="text"
            placeholder="Search tasks by title or description..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="input pl-10"
          />
          {search && (
            <button onClick={() => setSearch("")}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-[#4A5568] hover:text-[#8892B0]">
              <X className="w-4 h-4" />
            </button>
          )}
        </div>

        <select value={status} onChange={(e) => setStatus(e.target.value)}
          className="input w-full sm:w-40 cursor-pointer">
          {STATUS_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>

        <select value={category} onChange={(e) => setCategory(e.target.value)}
          className="input w-full sm:w-48 cursor-pointer">
          {CATEGORY_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>

        <select value={minRep} onChange={(e) => setMinRep(e.target.value)}
          className="input w-full sm:w-44 cursor-pointer">
          {REP_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>

        <select value={sort} onChange={(e) => setSort(e.target.value)}
          className="input w-full sm:w-44 cursor-pointer">
          {SORT_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
      </div>

      {hasFilters && (
        <div className="flex items-center gap-2 flex-wrap">
          <span className="flex items-center gap-1.5 text-xs text-[#8892B0]">
            <SlidersHorizontal className="w-3 h-3" /> Filters:
          </span>
          {status && (
            <button onClick={() => setStatus("")}
              className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-cyan/10 border border-cyan/20 text-xs text-cyan font-mono">
              {STATUS_OPTIONS.find(o => o.value === status)?.label} <X className="w-3 h-3" />
            </button>
          )}
          {category && (
            <button onClick={() => setCategory("")}
              className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-violet/10 border border-violet/20 text-xs text-violet font-mono">
              {category} <X className="w-3 h-3" />
            </button>
          )}
          {minRep && (
            <button onClick={() => setMinRep("")}
              className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-amber/10 border border-amber/20 text-xs text-amber font-mono">
              Rep {REP_OPTIONS.find(o => o.value === minRep)?.label} <X className="w-3 h-3" />
            </button>
          )}
          <button onClick={() => { setSearch(""); setStatus(""); setCategory(""); setMinRep(""); setSort("reward_desc"); }}
            className="text-xs text-[#4A5568] hover:text-[#8892B0] ml-1 underline">
            Clear all
          </button>
        </div>
      )}
    </div>
  );
}