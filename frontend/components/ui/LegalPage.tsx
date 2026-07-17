import { ReactNode } from "react";

export function LegalPage({
  title,
  updated,
  children,
}: {
  title: string;
  updated: string;
  children: ReactNode;
}) {
  return (
    <div className="max-w-3xl mx-auto px-4 sm:px-6 py-14 md:py-20">
      <div className="ag-eyebrow mb-5">Legal</div>
      <h1 className="ag-h1 text-4xl sm:text-5xl">{title}</h1>
      <p className="font-mono text-xs text-text-muted mt-4">Last updated: {updated}</p>
      <div className="ag-divider my-10" />
      <div className="space-y-10 text-text-secondary leading-relaxed text-[15px] [&_h2]:font-display [&_h2]:font-bold [&_h2]:text-xl [&_h2]:text-bone [&_h2]:mb-3 [&_ul]:list-disc [&_ul]:pl-5 [&_ul]:space-y-1.5 [&_strong]:text-bone">
        {children}
      </div>
    </div>
  );
}
