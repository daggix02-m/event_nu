const required = ["API_BASE_URL", "ADMIN_PANEL_SECRET", "JWT_SECRET"] as const;

export type AdminEnv = Record<(typeof required)[number], string>;

let cached: AdminEnv | null = null;

/**
 * Server-only env access. Fails fast at build/boot so a missing secret never
 * silently disables the admin gate. Never import this from client code.
 */
export function env(): AdminEnv {
  if (cached) return cached;
  const missing = required.filter((k) => !process.env[k]);
  if (missing.length > 0) {
    throw new Error(`admin: missing required env: ${missing.join(", ")}`);
  }
  cached = {
    API_BASE_URL: process.env.API_BASE_URL!,
    ADMIN_PANEL_SECRET: process.env.ADMIN_PANEL_SECRET!,
    JWT_SECRET: process.env.JWT_SECRET!,
  };
  return cached;
}