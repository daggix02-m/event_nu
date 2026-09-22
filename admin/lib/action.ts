import { NextResponse } from "next/server";
import { BackendError, callBackend } from "./backend";
import { withRetry } from "./session";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Shared mutation proxy: forwards a POST with an optional JSON body to a
 * backend admin action path, with the single-flight access-token refresh on
 * 401. Non-2xx responses are surfaced as {error:{code,message}}.
 */
export async function proxyAction(
  backendPath: string,
  body: unknown,
): Promise<NextResponse> {
  try {
    const { status, json } = await withRetry((pair) =>
      callBackend(backendPath, { method: "POST", body, pair }),
    );
    return NextResponse.json(json, { status });
  } catch (err) {
    const status = err instanceof BackendError ? err.status : 500;
    const code = err instanceof BackendError ? err.code : "upstream_error";
    const message = err instanceof BackendError ? err.message : "Event Nu API unavailable.";
    const body =
      status >= 400 && status < 500
        ? { error: { code, message } }
        : { error: { code: "upstream_error", message } };
    return NextResponse.json(body, { status });
  }
}