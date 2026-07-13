"use client";

import { useState } from "react";
import { Search, SlidersHorizontal, X } from "lucide-react";
import { CATEGORY_LABELS } from "@/lib/utils";

const CATEGORIES = [
  { value: "", label: "All Categories" },
  ...Object.entries(CATEGORY_LABELS).map(([value, label]) => ({ value, label })),
];

const SORT_OPTIONS = [
  { value: "reputation", label: "Top Reputation" },
  { value: "tasks",      label: "Most Tasks" },
  { value: "recent",     label: "Recently Active" },
  { value: "earned",     label: "Highest Earned" },
];

const STATUS_OPTIONS = [
  { value: "",  label: "Any Status" },
  { value: "1", label: "Active" },
  { value: "2", label: "Busy" },
  { value: "0", label: "Inactive" },
];

export function AgentFilters() {
  const [search, setSearch]     = useState("");
  const [category, setCategory] = useState("");
  const [sort, setSort]         = useState("reputation");
  const [status, setStatus]     = useState("");

  const hasFilters = search || category || status || sort !== "reputation";

  return (
    <div className="mb-8 space-y-4">
      {/* Search + filter row */}
      <div className="flex flex-col sm:flex-row gap-3">

        {/* Search */}
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#6B6355]" />
          <input
            type="text"
            placeholder="Search agents by name or capability..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="input pl-10"
          />
          {search && (
            <button
              onClick={() => setSearch("")}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-[#6B6355] hover:text-[#A89F8D] transition-colors"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>

        {/* Category */}
        <select
          value={category}
          onChange={(e) => setCategory(e.target.value)}
          className="input w-full sm:w-48 cursor-pointer"
        >
          {CATEGORIES.map((c) => (
            <option key={c.value} value={c.value}>{c.label}</option>
          ))}
        </select>

        {/* Status */}
        <select
          value={status}
          onChange={(e) => setStatus(e.target.value)}
          className="input w-full sm:w-40 cursor-pointer"
        >
          {STATUS_OPTIONS.map((s) => (
            <option key={s.value} value={s.value}>{s.label}</option>
          ))}
        </select>

        {/* Sort */}
        <select
          value={sort}
          onChange={(e) => setSort(e.target.value)}
          className="input w-full sm:w-48 cursor-pointer"
        >
          {SORT_OPTIONS.map((s) => (
            <option key={s.value} value={s.value}>{s.label}</option>
          ))}
        </select>
      </div>

      {/* Active filter pills */}
      {hasFilters && (
        <div className="flex items-center gap-2 flex-wrap">
          <span className="flex items-center gap-1.5 text-xs text-[#A89F8D]">
            <SlidersHorizontal className="w-3 h-3" /> Active filters:
          </span>
          {category && (
            <button
              onClick={() => setCategory("")}
              className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-cyan/10 border border-cyan/20 text-xs text-cyan font-mono hover:bg-cyan/20 transition-colors"
            >
              {CATEGORY_LABELS[Number(category)]}
              <X className="w-3 h-3" />
            </button>
          )}
          {status && (
            <button
              onClick={() => setStatus("")}
              className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-violet/10 border border-violet/20 text-xs text-violet font-mono hover:bg-violet/20 transition-colors"
            >
              {STATUS_OPTIONS.find(s => s.value === status)?.label}
              <X className="w-3 h-3" />
            </button>
          )}
          {sort !== "reputation" && (
            <button
              onClick={() => setSort("reputation")}
              className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-[#2A241B] border border-[#2A241B] text-xs text-[#A89F8D] font-mono hover:bg-[#3A3226] transition-colors"
            >
              Sort: {SORT_OPTIONS.find(s => s.value === sort)?.label}
              <X className="w-3 h-3" />
            </button>
          )}
          <button
            onClick={() => { setSearch(""); setCategory(""); setStatus(""); setSort("reputation"); }}
            className="text-xs text-[#6B6355] hover:text-[#A89F8D] transition-colors ml-1 underline"
          >
            Clear all
          </button>
        </div>
      )}
    </div>
  );
}