import { NextResponse } from "next/server";
import { callBackend } from "@/lib/backend";
import { clearPair, readPair } from "@/lib/session";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Logout proxy: revokes the refresh token server-side then clears the cookies.
 * Best-effort — even if the backend revoke fails we clear local state so the
 * browser can't reuse the pair.
 */
export async function POST() {
  const pair = await readPair();
  if (pair.refresh) {
    try {
      await callBackend("/api/v1/auth/logout", {
        method: "POST",
        body: { refresh_token: pair.refresh },
      });
    } catch (err) {
      console.warn("admin logout backend revoke failed", err);
    }
  }
  await clearPair();
  return NextResponse.json({ status: "logged_out" });
}