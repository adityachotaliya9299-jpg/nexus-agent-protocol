"use client";

import { useEffect } from "react";

/**
 * Global scroll engine.
 * - Watches every `.rv` / `.wr` element (including ones added after route
 *   changes, via MutationObserver) and stamps `.rv-in` when it enters the
 *   viewport — powering the whole scroll-triggered reveal system in CSS.
 * - Maintains `--scroll-p` on <html> as a fallback scroll-progress driver
 *   for browsers without `animation-timeline: scroll()`.
 */
export function ScrollFX() {
  useEffect(() => {
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) {
            e.target.classList.add("rv-in", "wr-in");
            io.unobserve(e.target);
          }
        }
      },
      { threshold: 0.12, rootMargin: "0px 0px -6% 0px" }
    );

    const scan = () => {
      document
        .querySelectorAll<HTMLElement>(".rv:not(.rv-in), .wr:not(.wr-in)")
        .forEach((el) => io.observe(el));
    };
    scan();

    const mo = new MutationObserver(() => scan());
    mo.observe(document.body, { childList: true, subtree: true });

    let raf = 0;
    const onScroll = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => {
        const h = document.documentElement;
        const p = h.scrollTop / Math.max(1, h.scrollHeight - h.clientHeight);
        h.style.setProperty("--scroll-p", p.toFixed(4));
      });
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);

    return () => {
      io.disconnect();
      mo.disconnect();
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
      cancelAnimationFrame(raf);
    };
  }, []);

  return null;
}
