"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

function useAction(path: string) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function run() {
    setBusy(true);
    setError(null);
    try {
      const res = await fetch(path, { method: "POST", headers: { "Content-Type": "application/json" } });
      const json = await res.json().catch(() => null);
      if (!res.ok) {
        setError(json?.error?.message ?? "Action failed.");
        return;
      }
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  return { busy, error, run };
}

const btn =
  "rounded-md px-3 py-1.5 text-xs font-medium transition-colors disabled:opacity-50";

export function ApproveButton({ id }: { id: string }) {
  const { busy, error, run } = useAction(`/api/admin/organizer-applications/${id}/approve`);
  return (
    <>
      <button
        onClick={run}
        disabled={busy}
        className={`${btn} bg-ok-container/40 text-ok hover:bg-ok-container/60`}
      >
        {busy ? "…" : "Approve"}
      </button>
      {error && <span className="text-xs text-error">{error}</span>}
    </>
  );
}

export function RejectButton({ id }: { id: string }) {
  const { busy, error, run } = useAction(`/api/admin/organizer-applications/${id}/reject`);
  return (
    <>
      <button
        onClick={run}
        disabled={busy}
        className={`${btn} bg-error-container/30 text-error hover:bg-error-container/50`}
      >
        {busy ? "…" : "Reject"}
      </button>
      {error && <span className="text-xs text-error">{error}</span>}
    </>
  );
}