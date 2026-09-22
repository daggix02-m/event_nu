import { jwtVerify } from "jose";
import { NextResponse, type NextRequest } from "next/server";
import { ACCESS_COOKIE } from "./lib/session";

const SECRET = () => new TextEncoder().encode(process.env.JWT_SECRET ?? "");

/**
 * UX gate for the admin console: the access cookie must be a valid JWT signed
 * with the shared JWT_SECRET and carry role=admin. This only controls what the
 * UI shows; the backend's RequireAdmin check is the real authority. A stale
 * (refreshable) access token just redirects to /login, where the session route
 * refreshes silently. API routes are excluded — they self-refresh and the
 * backend re-checks admin on every call.
 */
export default async function proxy(request: NextRequest) {
  const token = request.cookies.get(ACCESS_COOKIE)?.value;

  if (!token || !process.env.JWT_SECRET) {
    return redirectToLogin(request);
  }

  try {
    const { payload } = await jwtVerify(token, SECRET(), {
      algorithms: ["HS256"],
    });
    if (payload.role !== "admin") {
      return redirectToLogin(request);
    }
  } catch {
    return redirectToLogin(request);
  }

  return NextResponse.next();
}

function redirectToLogin(request: NextRequest) {
  const login = new URL("/login", request.url);
  const next = request.nextUrl.pathname + request.nextUrl.search;
  login.searchParams.set("next", next);
  return NextResponse.redirect(login);
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|login|api).*)"],
};