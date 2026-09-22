import { NextResponse } from "next/server";
import { callBackend } from "@/lib/backend";
import { panelSecret, timingSafeEqual, writePair } from "@/lib/session";
import type { AuthResponse } from "@/lib/types";
import { z } from "zod";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
  panel_secret: z.string().min(1),
});

/**
 * Login proxy: validates the shared admin panel secret, exchanges the user's
 * credentials with the Event Nu API, refuses non-admin accounts (the backend's
 * RequireAdmin is the real authority; this is the UX gate), and stores the
 * token pair as httpOnly cookies so the browser never sees them.
 */
export async function POST(request: Request) {
  let body: z.infer<typeof loginSchema>;
  try {
    body = loginSchema.parse(await request.json());
  } catch {
    return NextResponse.json({ error: { code: "validation_error", message: "email, password and panel_secret are required." } }, { status: 422 });
  }

  if (!timingSafeEqual(body.panel_secret, panelSecret())) {
    return NextResponse.json({ error: { code: "invalid_panel_secret", message: "Invalid admin panel secret." } }, { status: 401 });
  }

  try {
    const { json } = await callBackend("/api/v1/auth/login", {
      method: "POST",
      body: { email: body.email, password: body.password },
    });
    const auth = (json as { data: AuthResponse }).data;
    if (auth?.user?.role !== "admin") {
      return NextResponse.json({ error: { code: "forbidden", message: "This account is not an admin." } }, { status: 403 });
    }
    await writePair({ access: auth.access_token, refresh: auth.refresh_token }, auth.expires_in);
    return NextResponse.json({ user: auth.user, expires_in: auth.expires_in });
  } catch (err) {
    console.error("admin login proxy failed", err);
    return NextResponse.json({ error: { code: "login_failed", message: "Login failed. Check credentials." } }, { status: 401 });
  }
}