import type { CSSProperties, ReactNode } from "react";

type Variant = "up" | "left" | "right" | "scale" | "blur" | "flip";

const VARIANT_CLASS: Record<Variant, string> = {
  up: "",
  left: "rv-left",
  right: "rv-right",
  scale: "rv-scale",
  blur: "rv-blur",
  flip: "rv-flip",
};

/**
 * Scroll-triggered reveal wrapper. Server-safe (no JS of its own) —
 * the global <ScrollFX/> observer flips it on when scrolled into view.
 */
export function Reveal({
  children,
  variant = "up",
  delay = 0,
  className = "",
  as: Tag = "div",
}: {
  children: ReactNode;
  variant?: Variant;
  delay?: number;
  className?: string;
  as?: any;
}) {
  return (
    <Tag
      className={`rv ${VARIANT_CLASS[variant]} ${className}`}
      style={{ "--rv-delay": `${delay}ms` } as CSSProperties}
    >
      {children}
    </Tag>
  );
}

/** Splits text into words that slide up out of a masked line, staggered. */
export function WordReveal({
  text,
  className = "",
  baseDelay = 0,
  step = 70,
}: {
  text: string;
  className?: string;
  baseDelay?: number;
  step?: number;
}) {
  return (
    <span className={`wr ${className}`}>
      {text.split(" ").map((word, i) => (
        <span key={i} className="word-reveal">
          <span style={{ "--wr-delay": `${baseDelay + i * step}ms` } as CSSProperties}>
            {word}
            {i < text.split(" ").length - 1 ? " " : ""}
          </span>
        </span>
      ))}
    </span>
  );
}
