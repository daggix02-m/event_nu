import { StatusBadge } from "@/components/status-badge";
import type { AdminOrganizerApplication } from "@/lib/types";
import { ApproveButton, RejectButton } from "./review-buttons";

function fmt(ts: string | null): string {
  if (!ts) return "—";
  return new Date(ts).toLocaleString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function ApplicationRow({
  app,
  divider,
}: {
  app: AdminOrganizerApplication;
  divider: boolean;
}) {
  const reviewable = app.status === "pending";

  return (
    <div
      className={`flex flex-wrap items-center justify-between gap-3 bg-surface-container px-5 py-4 ${
        divider ? "border-b border-outline-variant/40" : ""
      }`}
    >
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-3">
          <p className="text-sm font-semibold text-on-surface">{app.requested_name}</p>
          <StatusBadge value={app.status} />
        </div>
        <p className="mt-1 truncate text-xs text-on-surface-variant">
          {app.applicant_username ? `@${app.applicant_username}` : "unknown"} ·{" "}
          {app.applicant_email ?? "no email"} · submitted {fmt(app.submitted_at)}
        </p>
        {app.bio && (
          <p className="mt-2 line-clamp-2 text-sm text-on-surface-variant">{app.bio}</p>
        )}
      </div>
      <div className="flex shrink-0 items-center gap-2">
        {reviewable && (
          <>
            <ApproveButton id={app.id} />
            <RejectButton id={app.id} />
          </>
        )}
      </div>
    </div>
  );
}