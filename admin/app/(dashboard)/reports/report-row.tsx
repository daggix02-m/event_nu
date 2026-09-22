import { StatusBadge } from "@/components/status-badge";
import type { AdminReport } from "@/lib/types";
import { ResolveButton } from "./resolve-button";

function fmt(ts: string): string {
  return new Date(ts).toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function ReportRow({
  report,
  divider,
}: {
  report: AdminReport;
  divider: boolean;
}) {
  const open = report.status === "open" || report.status === "under_review";
  return (
    <div
      className={`flex flex-wrap items-center justify-between gap-3 bg-surface-container px-5 py-4 ${
        divider ? "border-b border-outline-variant/40" : ""
      }`}
    >
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-3">
          <p className="text-sm font-semibold text-on-surface">
            <span className="normal-case">{report.entity_type}</span>
            <span className="text-on-surface-variant"> · {report.entity_id.slice(0, 8)}</span>
          </p>
          <StatusBadge value={report.status} />
        </div>
        <p className="mt-1 text-xs text-on-surface-variant">
          <span className="capitalize">{report.reason_code}</span> · reported by{" "}
          {report.reporter_user_id.slice(0, 8)} · {fmt(report.created_at)}
        </p>
        {report.description && (
          <p className="mt-2 line-clamp-2 text-sm text-on-surface-variant">
            {report.description}
          </p>
        )}
      </div>
      <div className="flex shrink-0 items-center gap-2">
        {open && <ResolveButton id={report.id} />}
      </div>
    </div>
  );
}