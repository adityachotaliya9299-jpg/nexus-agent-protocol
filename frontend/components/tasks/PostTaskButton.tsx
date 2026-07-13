"use client";

import { useState } from "react";
import { Plus, X, ChevronDown, Info } from "lucide-react";

export function PostTaskButton() {
  const [open, setOpen] = useState(false);

  return (
    <>
      <button onClick={() => setOpen(true)} className="btn-primary shrink-0">
        <Plus className="w-4 h-4" />
        Post Task
      </button>

      {/* Modal backdrop */}
      {open && (
        <div
          className="fixed inset-0 z-50 bg-[#0B0A08]/80 backdrop-blur-sm flex items-center justify-center p-4"
          onClick={(e) => e.target === e.currentTarget && setOpen(false)}
        >
          <div className="w-full max-w-lg card border-[#2A241B] shadow-2xl">

            {/* Modal header */}
            <div className="flex items-center justify-between p-6 border-b border-[#2A241B]">
              <div>
                <h2 className="font-display font-bold text-xl text-[#F4EFE6]">Post a Task</h2>
                <p className="text-xs text-[#A89F8D] mt-0.5">ETH reward held in escrow until completion</p>
              </div>
              <button onClick={() => setOpen(false)}
                className="p-2 rounded-md text-[#6B6355] hover:text-[#F4EFE6] hover:bg-[#2A241B]/50 transition-colors">
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Form */}
            <div className="p-6 space-y-5">

              {/* Title */}
              <div>
                <label className="label mb-1.5 block">Task Title</label>
                <input type="text" placeholder="e.g. Audit Uniswap V4 Hook Contract" className="input" />
              </div>

              {/* Description */}
              <div>
                <label className="label mb-1.5 block">Description</label>
                <textarea rows={4} placeholder="Describe the task requirements, deliverables, and acceptance criteria..." className="input resize-none" />
              </div>

              {/* Category + Deadline row */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="label mb-1.5 block">Category</label>
                  <div className="relative">
                    <select className="input cursor-pointer appearance-none pr-8">
                      <option>Development</option>
                      <option>Security Audit</option>
                      <option>Research</option>
                      <option>Trading</option>
                      <option>Creative</option>
                    </select>
                    <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#6B6355] pointer-events-none" />
                  </div>
                </div>
                <div>
                  <label className="label mb-1.5 block">Deadline</label>
                  <div className="relative">
                    <select className="input cursor-pointer appearance-none pr-8">
                      <option>24 hours</option>
                      <option>3 days</option>
                      <option>7 days</option>
                      <option>14 days</option>
                      <option>30 days</option>
                    </select>
                    <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#6B6355] pointer-events-none" />
                  </div>
                </div>
              </div>

              {/* Reward + Min rep row */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="label mb-1.5 block">Reward (ETH)</label>
                  <input type="number" step="0.01" placeholder="0.00" className="input" />
                </div>
                <div>
                  <label className="label mb-1.5 block">Min Reputation</label>
                  <div className="relative">
                    <select className="input cursor-pointer appearance-none pr-8">
                      <option value="0">No minimum</option>
                      <option value="5000">50%+</option>
                      <option value="6000">60%+</option>
                      <option value="7000">70%+</option>
                      <option value="8000">80%+</option>
                    </select>
                    <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#6B6355] pointer-events-none" />
                  </div>
                </div>
              </div>

              {/* Escrow info */}
              <div className="flex items-start gap-3 px-4 py-3 rounded-lg bg-cyan/5 border border-cyan/20">
                <Info className="w-4 h-4 text-cyan shrink-0 mt-0.5" />
                <p className="text-xs text-[#A89F8D] leading-relaxed">
                  Your ETH reward will be held in escrow by the TaskMarketplace contract and released
                  automatically when you approve the agent's work. You can raise a dispute if needed.
                </p>
              </div>
            </div>

            {/* Footer */}
            <div className="flex items-center gap-3 p-6 border-t border-[#2A241B]">
              <button onClick={() => setOpen(false)} className="btn-secondary flex-1 justify-center">
                Cancel
              </button>
              <button className="btn-primary flex-1 justify-center">
                Post Task + Escrow ETH
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}