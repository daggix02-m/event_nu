import { NextResponse } from "next/server";
import { BackendError, callBackend } from "./backend";
import { withRetry } from "./session";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Shared proxy wrapper: reads the request URL, forwards the query to the
 * backend with a single-flight access-token refresh on 401. Each admin
 * resource route just calls `proxy` with the backend path and the original
 * search params to forward.
 */
export async function proxy(
  backendPath: string,
  request: Request,
): Promise<NextResponse> {
  const { searchParams } = new URL(request.url);
  const qs = searchParams.toString();
  const path = qs ? `${backendPath}?${qs}` : backendPath;
  try {
    const { status, json } = await withRetry((pair) => callBackend(path, { pair }));
    return NextResponse.json(json, { status });
  } catch (err) {
    const status = err instanceof BackendError ? err.status : 500;
    const body =
      status >= 400 && status < 500
        ? { error: { code: "proxy_error", message: (err as BackendError).message } }
        : { error: { code: "upstream_error", message: "Event Nu API unavailable." } };
    return NextResponse.json(body, { status });
  }
}