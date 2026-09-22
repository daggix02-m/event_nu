import { cookies } from "next/headers";
import { BackendError, callBackend, type TokenPair } from "./backend";
import { env } from "./env";
import type { AuthResponse } from "./types";

export const ACCESS_COOKIE = "ev_admin_access";
export const REFRESH_COOKIE = "ev_admin_refresh";

const cookieBase = () => ({
  httpOnly: true,
  sameSite: "lax" as const,
  secure: process.env.NODE_ENV === "production",
  path: "/",
});

/** Reads the stored token pair from request cookies. */
export async function readPair(): Promise<TokenPair> {
  const jar = await cookies();
  return {
    access: jar.get(ACCESS_COOKIE)?.value ?? "",
    refresh: jar.get(REFRESH_COOKIE)?.value ?? "",
  };
}

/** Writes a token pair as httpOnly cookies. */
export async function writePair(pair: TokenPair, expiresIn = 900): Promise<void> {
  const jar = await cookies();
  jar.set(ACCESS_COOKIE, pair.access, { ...cookieBase(), maxAge: expiresIn });
  jar.set(REFRESH_COOKIE, pair.refresh, { ...cookieBase(), maxAge: 30 * 24 * 60 * 60 });
}

/** Clears both auth cookies (logout). */
export async function clearPair(): Promise<void> {
  const jar = await cookies();
  jar.delete(ACCESS_COOKIE);
  jar.delete(REFRESH_COOKIE);
}

/**
 * Single-flight refresh cache, keyed by refresh token. When concurrent requests
 * all trip a 401 with the same refresh token they coalesce onto ONE backend
 * rotation call — the backend rotates and revokes the previous refresh token,
 * so parallel refresh attempts would race and one would be rejected. The cache
 * is cleared when the refresh resolves/rejects.
 */
const inFlight = new Map<string, Promise<{ pair: TokenPair; expiresIn: number }>>();

export async function refreshPair(
  current: TokenPair,
): Promise<{ pair: TokenPair; expiresIn: number }> {
  const key = current.refresh;
  const pending = inFlight.get(key);
  if (pending) return pending;

  const run = (async () => {
    const { json } = await callBackend("/api/v1/auth/refresh", {
      method: "POST",
      body: { refresh_token: current.refresh },
    });
    const auth = (json as { data: AuthResponse }).data;
    if (!auth?.access_token || !auth?.refresh_token) {
      throw new Error("admin: refresh response missing tokens");
    }
    return {
      pair: { access: auth.access_token, refresh: auth.refresh_token },
      expiresIn: auth.expires_in || 900,
    };
  })().finally(() => {
    inFlight.delete(key);
  });

  inFlight.set(key, run);
  return run;
}

/**
 * Runs a backend call once, replaying it after a single-flight access-token
 * refresh IF the first attempt failed with a 401. Non-auth failures propagate
 * untouched.
 */
export async function withRetry(
  attempt: (pair: TokenPair) => Promise<{ status: number; json: unknown }>,
): Promise<{ status: number; json: unknown }> {
  const pair = await readPair();
  try {
    return await attempt(pair);
  } catch (err) {
    const authErr = err as BackendError;
    if (!(err instanceof BackendError) || authErr.status !== 401 || !pair.refresh) {
      throw err;
    }
    const { pair: fresh, expiresIn } = await refreshPair(pair);
    await writePair(fresh, expiresIn);
    return attempt(fresh);
  }
}

/** Constant-time string comparison for the admin panel secret. */
export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}

export function panelSecret(): string {
  return env().ADMIN_PANEL_SECRET;
}