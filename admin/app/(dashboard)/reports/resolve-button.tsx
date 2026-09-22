"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

export function ResolveButton({ id }: { id: string }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function resolve() {
    setBusy(true);
    setError(null);
    try {
      const res = await fetch(`/api/admin/reports/${id}/resolve`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ resolution: "Handled from admin console." }),
      });
      const json = await res.json().catch(() => null);
      if (!res.ok) {
        setError(json?.error?.message ?? "Failed to resolve.");
        return;
      }
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <button
        onClick={resolve}
        disabled={busy}
        className="rounded-md bg-tertiary-container/20 px-3 py-1.5 text-xs font-medium text-tertiary transition-colors hover:bg-tertiary-container/30 disabled:opacity-50"
      >
        {busy ? "…" : "Mark resolved"}
      </button>
      {error && <span className="text-xs text-error">{error}</span>}
    </>
  );
}