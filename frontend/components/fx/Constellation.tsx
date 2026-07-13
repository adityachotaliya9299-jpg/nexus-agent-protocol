"use client";

import { useEffect, useRef } from "react";

type P = {
  x: number; y: number; z: number;
  vx: number; vy: number; vz: number;
  hue: 0 | 1 | 2; // 0 gold, 1 ember, 2 bone
};

const COLORS = [
  [242, 169, 59], // gold
  [255, 107, 61], // ember
  [244, 239, 230], // bone
] as const;

/**
 * "The Gathering" — a true 3D particle constellation rendered on canvas.
 * Points live in a 3D volume, drift slowly, and are perspective-projected
 * onto the screen with depth fog. Nearby nodes link with fading synapses.
 * The whole field parallaxes gently against the cursor and breathes on a
 * slow orbital rotation — the sky under which the agent economy trades.
 */
export function Constellation({
  density = 1,
  className = "",
  interactive = true,
}: {
  density?: number;
  className?: string;
  interactive?: boolean;
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    let w = 0, h = 0, dpr = Math.min(2, window.devicePixelRatio || 1);
    let raf = 0;
    let running = true;
    let particles: P[] = [];
    const FOV = 420;
    const DEPTH = 900;
    let mx = 0, my = 0;        // target mouse offset (-1..1)
    let cmx = 0, cmy = 0;      // smoothed
    let rot = 0;

    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      w = rect.width;
      h = rect.height;
      dpr = Math.min(2, window.devicePixelRatio || 1);
      canvas.width = Math.max(1, Math.floor(w * dpr));
      canvas.height = Math.max(1, Math.floor(h * dpr));
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

      const target = Math.min(190, Math.floor((w * h) / 11000) * density);
      particles = Array.from({ length: Math.max(40, target) }, () => ({
        x: (Math.random() - 0.5) * w * 1.4,
        y: (Math.random() - 0.5) * h * 1.4,
        z: Math.random() * DEPTH,
        vx: (Math.random() - 0.5) * 0.12,
        vy: (Math.random() - 0.5) * 0.12,
        vz: 0.18 + Math.random() * 0.35,
        hue: (Math.random() < 0.55 ? 0 : Math.random() < 0.7 ? 1 : 2) as P["hue"],
      }));
    };

    const project = (p: P, cosR: number, sinR: number) => {
      // slow orbital rotation around Y axis
      const rx = p.x * cosR - (p.z - DEPTH / 2) * sinR;
      const rz = p.x * sinR + (p.z - DEPTH / 2) * cosR + DEPTH / 2;
      const scale = FOV / (FOV + rz);
      return {
        sx: w / 2 + (rx + cmx * 60 * scale) * scale,
        sy: h / 2 + (p.y + cmy * 45 * scale) * scale,
        scale,
        z: rz,
      };
    };

    const frame = () => {
      if (!running) return;
      ctx.clearRect(0, 0, w, h);

      cmx += (mx - cmx) * 0.03;
      cmy += (my - cmy) * 0.03;
      rot += 0.0006;
      const cosR = Math.cos(rot), sinR = Math.sin(rot);

      const projected = particles.map((p) => {
        p.x += p.vx; p.y += p.vy; p.z -= p.vz;
        if (p.z < 1) { p.z = DEPTH; p.x = (Math.random() - 0.5) * w * 1.4; p.y = (Math.random() - 0.5) * h * 1.4; }
        if (p.x > w * 0.75) p.x = -w * 0.75; else if (p.x < -w * 0.75) p.x = w * 0.75;
        if (p.y > h * 0.75) p.y = -h * 0.75; else if (p.y < -h * 0.75) p.y = h * 0.75;
        return { p, ...project(p, cosR, sinR) };
      });

      // synapses between near neighbours (screen-space, capped for perf)
      const LINK = Math.min(130, w * 0.11);
      for (let i = 0; i < projected.length; i++) {
        const a = projected[i];
        if (a.scale <= 0) continue;
        for (let j = i + 1; j < projected.length; j++) {
          const b = projected[j];
          const dx = a.sx - b.sx, dy = a.sy - b.sy;
          const d2 = dx * dx + dy * dy;
          if (d2 > LINK * LINK) continue;
          const t = 1 - Math.sqrt(d2) / LINK;
          const depthFade = Math.min(a.scale, b.scale);
          const [r, g, bl] = COLORS[a.p.hue];
          ctx.strokeStyle = `rgba(${r},${g},${bl},${(t * 0.16 * depthFade).toFixed(3)})`;
          ctx.lineWidth = 0.7;
          ctx.beginPath();
          ctx.moveTo(a.sx, a.sy);
          ctx.lineTo(b.sx, b.sy);
          ctx.stroke();
        }
      }

      // nodes with depth fog + soft glow on the closest ones
      for (const { p, sx, sy, scale } of projected) {
        if (scale <= 0 || sx < -20 || sx > w + 20 || sy < -20 || sy > h + 20) continue;
        const [r, g, b] = COLORS[p.hue];
        const alpha = Math.min(0.9, scale * 0.85);
        const radius = Math.max(0.4, 2.3 * scale);

        if (scale > 0.72) {
          const glow = ctx.createRadialGradient(sx, sy, 0, sx, sy, radius * 5);
          glow.addColorStop(0, `rgba(${r},${g},${b},${(alpha * 0.35).toFixed(3)})`);
          glow.addColorStop(1, "rgba(0,0,0,0)");
          ctx.fillStyle = glow;
          ctx.beginPath();
          ctx.arc(sx, sy, radius * 5, 0, Math.PI * 2);
          ctx.fill();
        }

        ctx.fillStyle = `rgba(${r},${g},${b},${alpha.toFixed(3)})`;
        ctx.beginPath();
        ctx.arc(sx, sy, radius, 0, Math.PI * 2);
        ctx.fill();
      }

      raf = requestAnimationFrame(frame);
    };

    const onMouse = (e: MouseEvent) => {
      mx = (e.clientX / window.innerWidth - 0.5) * 2;
      my = (e.clientY / window.innerHeight - 0.5) * 2;
    };

    const vis = new IntersectionObserver(([entry]) => {
      const shouldRun = entry.isIntersecting && !document.hidden;
      if (shouldRun && !running) { running = true; raf = requestAnimationFrame(frame); }
      else if (!shouldRun) { running = false; cancelAnimationFrame(raf); }
    });

    const onVisibility = () => {
      if (document.hidden) { running = false; cancelAnimationFrame(raf); }
      else if (!running) { running = true; raf = requestAnimationFrame(frame); }
    };

    resize();
    window.addEventListener("resize", resize);
    if (interactive && !reduced) window.addEventListener("mousemove", onMouse, { passive: true });
    document.addEventListener("visibilitychange", onVisibility);
    vis.observe(canvas);

    if (reduced) {
      // draw one static frame only
      running = true;
      const cosR = 1, sinR = 0;
      particles.forEach((p) => {
        const { sx, sy, scale } = project(p, cosR, sinR);
        const [r, g, b] = COLORS[p.hue];
        ctx.fillStyle = `rgba(${r},${g},${b},${Math.min(0.8, scale * 0.8).toFixed(3)})`;
        ctx.beginPath();
        ctx.arc(sx, sy, Math.max(0.4, 2 * scale), 0, Math.PI * 2);
        ctx.fill();
      });
      running = false;
    } else {
      raf = requestAnimationFrame(frame);
    }

    return () => {
      running = false;
      cancelAnimationFrame(raf);
      window.removeEventListener("resize", resize);
      window.removeEventListener("mousemove", onMouse);
      document.removeEventListener("visibilitychange", onVisibility);
      vis.disconnect();
    };
  }, [density, interactive]);

  return (
    <canvas
      ref={canvasRef}
      className={`absolute inset-0 w-full h-full ${className}`}
      aria-hidden
    />
  );
}
