import type { ReactNode } from "react";

/**
 * Infinite horizontal marquee. Content is duplicated so the -50%
 * translate loop is seamless. Pauses on hover, fades at the edges.
 */
export function Marquee({
  children,
  className = "",
  duration = 42,
  reverse = false,
}: {
  children: ReactNode;
  className?: string;
  duration?: number;
  reverse?: boolean;
}) {
  return (
    <div className={`overflow-hidden marquee-mask ${className}`}>
      <div
        className="ticker-track"
        style={{
          animationDuration: `${duration}s`,
          animationDirection: reverse ? "reverse" : "normal",
        }}
      >
        <div className="flex items-center shrink-0">{children}</div>
        <div className="flex items-center shrink-0" aria-hidden>
          {children}
        </div>
      </div>
    </div>
  );
}
