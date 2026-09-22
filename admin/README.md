# Event Nu Admin

Next.js 16 BFF-powered admin dashboard for managing organizer applications, event moderation, and reports.

## Prerequisites

- Node 22+
- Backend API running on `http://localhost:8080`

## Environment

Copy `.env.example` to `.env.local` and set values:

| Variable | Description |
|---|---|
| `API_BASE_URL` | Backend API origin (default `http://localhost:8080`) |
| `ADMIN_PANEL_SECRET` | Shared panel secret (`ADMIN_PANEL_SECRET` in backend `.env`) |
| `JWT_SECRET` | JWT signing key (must match `JWT_SECRET` in backend `.env`) |

## Development

```bash
npm install
npm run dev          # http://localhost:3000
```

Login with any admin account. The panel secret gates access before backend auth is verified.

## Build & Lint

```bash
npm run build
npm run lint
```

## Architecture

```
app/
  api/auth/          BFF auth routes (login, logout, session, refresh)
  api/admin/         BFF admin routes (proxy + mutation actions)
  (dashboard)/       Server-rendered admin pages (login-gated by proxy.ts middleware)
lib/
  backend.ts         Direct backend HTTP client (for auth endpoints)
  session.ts         Cookie management + single-flight refresh
  admin.ts           Server pages → own /api/admin/* route handlers
  proxy.ts           Proxy + action helpers for API route handlers
proxy.ts             Next middleware: admin role gate (jose verify)
```

Pages fetch their own `/api/admin/*` route handlers (not the backend directly) to keep `Set-Cookie` headers in the response and avoid Server Component cookie-setting restrictions.
