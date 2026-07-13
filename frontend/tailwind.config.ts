import type { Config } from "tailwindcss";

/**
 * AGORA design system — "Obsidian & Solar"
 * Warm ink-black surfaces, bone type, molten gold/ember accents.
 *
 * NOTE: legacy token names (cyan, violet, emerald…) are kept as aliases so
 * older components inherit the new palette without a rewrite.
 */
const config: Config = {
  content: ["./pages/**/*.{js,ts,jsx,tsx,mdx}", "./components/**/*.{js,ts,jsx,tsx,mdx}", "./app/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        // core surfaces
        void: "#0B0A08",
        surface: "#14110D",
        raised: "#1A1610",
        border: "#2A241B",
        muted: "#3A3226",
        // accents
        gold: "#F2A93B",
        "gold-bright": "#FFC46B",
        ember: "#FF6B3D",
        jade: "#57C99B",
        sky: "#64B6E7",
        orchid: "#C84B8E",
        blood: "#E5484D",
        // text
        bone: "#F4EFE6",
        "text-primary": "#F4EFE6",
        "text-secondary": "#A89F8D",
        "text-muted": "#6B6355",
        // ── legacy aliases (old components keep working) ──
        cyan: "#F2A93B",
        violet: "#FF6B3D",
        emerald: "#57C99B",
        amber: "#FFC46B",
        rose: "#E5484D",
      },
      fontFamily: {
        display: ["Syne", "system-ui", "sans-serif"],
        serif: ["Fraunces", "Georgia", "serif"],
        body: ["Figtree", "system-ui", "sans-serif"],
        mono: ["IBM Plex Mono", "Fira Code", "monospace"],
      },
      animation: {
        "pulse-slow": "pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite",
        ticker: "ticker 30s linear infinite",
        glow: "glow 2s ease-in-out infinite alternate",
        "spin-slow": "spin 14s linear infinite",
        float: "float 7s ease-in-out infinite",
      },
      keyframes: {
        ticker: { "0%": { transform: "translateX(0)" }, "100%": { transform: "translateX(-50%)" } },
        glow: {
          from: { boxShadow: "0 0 10px rgba(242,169,59,0.15)" },
          to: { boxShadow: "0 0 30px rgba(242,169,59,0.45)" },
        },
        float: {
          "0%,100%": { transform: "translateY(0)" },
          "50%": { transform: "translateY(-14px)" },
        },
      },
    },
  },
  plugins: [],
};
export default config;
