import { env } from "./env";

export interface TokenPair {
  access: string;
  refresh: string;
}

export class BackendError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
  ) {
    super(message);
    this.name = "BackendError";
  }
}

/**
 * Calls the Event Nu API. `pair` may be empty for anonymous endpoints.
 * Errors are normalized to BackendError so callers can distinguish a token
 * failure (401) from a server/validation failure.
 */
export async function callBackend(
  path: string,
  opts: { method?: string; body?: unknown; pair?: TokenPair } = {},
): Promise<{ status: number; json: unknown }> {
  const { API_BASE_URL } = env();
  const headers: Record<string, string> = { Accept: "application/json" };
  if (opts.body !== undefined) headers["Content-Type"] = "application/json";
  if (opts.pair?.access) headers.Authorization = `Bearer ${opts.pair.access}`;

  const res = await fetch(`${API_BASE_URL}${path}`, {
    method: opts.method ?? "GET",
    headers,
    body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
    cache: "no-store",
    signal: AbortSignal.timeout(15_000),
  });

  let json: unknown = null;
  try {
    json = await res.json();
  } catch {
    json = null;
  }
  if (!res.ok) {
    const err = (json as { error?: { code?: string; message?: string } })?.error;
    throw new BackendError(res.status, err?.code ?? "backend_error", err?.message ?? `backend ${res.status}`);
  }
  return { status: res.status, json };
}