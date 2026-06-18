import type { Config } from "tailwindcss";
const config: Config = {
  content: ["./pages/**/*.{js,ts,jsx,tsx,mdx}","./components/**/*.{js,ts,jsx,tsx,mdx}","./app/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        void: "#080B12", surface: "#0D1120", border: "#1A2035", muted: "#2A3555",
        cyan: "#00E5FF", violet: "#8B5CF6", emerald: "#10B981", amber: "#F59E0B", rose: "#F43F5E",
        "text-primary": "#F0F4FF", "text-secondary": "#8892B0", "text-muted": "#4A5568",
      },
      fontFamily: {
        display: ["Space Grotesk", "system-ui", "sans-serif"],
        body: ["Inter", "system-ui", "sans-serif"],
        mono: ["JetBrains Mono", "Fira Code", "monospace"],
      },
      animation: {
        "pulse-slow": "pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite",
        "ticker": "ticker 30s linear infinite",
        "glow": "glow 2s ease-in-out infinite alternate",
      },
      keyframes: {
        ticker: { "0%": { transform: "translateX(0)" }, "100%": { transform: "translateX(-50%)" } },
        glow: { "from": { boxShadow: "0 0 10px rgba(0,229,255,0.2)" }, "to": { boxShadow: "0 0 30px rgba(0,229,255,0.6)" } },
      },
    },
  },
  plugins: [],
};
export default config;