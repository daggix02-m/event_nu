"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";

function LoginFormInner() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [secret, setSecret] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password, panel_secret: secret }),
      });
      const json = await res.json().catch(() => null);
      if (!res.ok) {
        setError(json?.error?.message ?? "Login failed.");
        return;
      }
      const next = searchParams.get("next");
      router.push(next && next.startsWith("/") ? next : "/");
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  const input =
    "w-full rounded-md border border-outline-variant/60 bg-surface-low px-3 py-2 text-sm text-on-surface placeholder:text-on-surface-variant/60 outline-none focus:border-neon";

  return (
    <div className="flex min-h-screen items-center justify-center px-6">
      <div className="w-full max-w-sm">
        <div className="mb-8 flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-neon font-bold text-on-primary">
            EN
          </div>
          <div>
            <h1 className="text-lg font-semibold text-on-surface">Event Nu</h1>
            <p className="text-sm text-on-surface-variant">Admin console</p>
          </div>
        </div>
        <form onSubmit={submit} className="space-y-4">
          <div className="space-y-1.5">
            <label htmlFor="email" className="text-xs text-on-surface-variant">
              Email
            </label>
            <input
              id="email"
              type="email"
              required
              autoComplete="username"
              className={input}
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>
          <div className="space-y-1.5">
            <label htmlFor="password" className="text-xs text-on-surface-variant">
              Password
            </label>
            <input
              id="password"
              type="password"
              required
              autoComplete="current-password"
              className={input}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>
          <div className="space-y-1.5">
            <label htmlFor="secret" className="text-xs text-on-surface-variant">
              Admin panel secret
            </label>
            <input
              id="secret"
              type="password"
              required
              autoComplete="off"
              className={input}
              value={secret}
              onChange={(e) => setSecret(e.target.value)}
            />
          </div>
          {error && (
            <p className="rounded-md bg-error-container/20 px-3 py-2 text-sm text-on-error-container">
              {error}
            </p>
          )}
          <button
            type="submit"
            disabled={busy}
            className="w-full rounded-md bg-primary px-3 py-2 text-sm font-semibold text-on-primary transition-colors hover:bg-primary-container disabled:opacity-60"
          >
            {busy ? "Signing in…" : "Sign in"}
          </button>
        </form>
      </div>
    </div>
  );
}

export function LoginForm() {
  return (
    <Suspense>
      <LoginFormInner />
    </Suspense>
  );
}