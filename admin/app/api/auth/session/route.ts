import { NextResponse } from "next/server";
import { BackendError, callBackend } from "@/lib/backend";
import { withRetry } from "@/lib/session";
import type { User } from "@/lib/types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Returns the authenticated admin's profile. Used by dashboard layouts / pages
 * to show who's logged in without a client round-trip. The access cookie is
 * forwarded to the backend; a single-flight refresh is attempted once on 401.
 */
export async function GET() {
  try {
    const { json } = await withRetry((pair) => callBackend("/api/v1/users/me", { pair }));
    const user = (json as { data: User }).data;
    if (!user?.id || user.role !== "admin") {
      return NextResponse.json({ error: { code: "forbidden", message: "Not an admin." } }, { status: 403 });
    }
    return NextResponse.json({ user });
  } catch (err) {
    const status = err instanceof BackendError ? err.status : 500;
    return NextResponse.json(
      { error: { code: "session_expired", message: "Please log in again." } },
      { status: status >= 400 && status < 500 ? status : 500 },
    );
  }
}