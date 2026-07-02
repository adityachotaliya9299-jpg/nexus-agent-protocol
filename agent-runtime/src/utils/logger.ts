// ── Logger ────────────────────────────────────────────────────
// Simple structured logger with timestamps and log levels.

type Level = "INFO" | "WARN" | "ERROR" | "DEBUG" | "ACTION" | "CHAIN";

function log(level: Level, context: string, message: string, data?: unknown) {
  const ts    = new Date().toISOString();
  const color = {
    INFO:   "\x1b[36m",   // cyan
    WARN:   "\x1b[33m",   // yellow
    ERROR:  "\x1b[31m",   // red
    DEBUG:  "\x1b[90m",   // gray
    ACTION: "\x1b[32m",   // green
    CHAIN:  "\x1b[35m",   // magenta
  }[level];
  const reset = "\x1b[0m";

  const prefix = `${color}[${level}]${reset} ${ts} [${context}]`;
  if (data !== undefined) {
    console.log(`${prefix} ${message}`, typeof data === "object" ? JSON.stringify(data, null, 2) : data);
  } else {
    console.log(`${prefix} ${message}`);
  }
}

export const logger = {
  info:   (ctx: string, msg: string, data?: unknown) => log("INFO",   ctx, msg, data),
  warn:   (ctx: string, msg: string, data?: unknown) => log("WARN",   ctx, msg, data),
  error:  (ctx: string, msg: string, data?: unknown) => log("ERROR",  ctx, msg, data),
  debug:  (ctx: string, msg: string, data?: unknown) => log("DEBUG",  ctx, msg, data),
  action: (ctx: string, msg: string, data?: unknown) => log("ACTION", ctx, msg, data),
  chain:  (ctx: string, msg: string, data?: unknown) => log("CHAIN",  ctx, msg, data),
};