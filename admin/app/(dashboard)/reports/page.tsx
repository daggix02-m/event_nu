import { listReports } from "@/lib/admin";
import { ReportRow } from "./report-row";

export const dynamic = "force-dynamic";

export default async function ReportsPage() {
  const page = await listReports({ page: 1, limit: 50 });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-on-surface">Reports</h1>
        <p className="mt-1 text-sm text-on-surface-variant">
          {page.pagination.total} reports
        </p>
      </div>

      {page.data.length === 0 ? (
        <p className="rounded-lg border border-dashed border-outline-variant/60 px-4 py-8 text-center text-sm text-on-surface-variant">
          No reports.
        </p>
      ) : (
        <div className="overflow-hidden rounded-lg border border-outline-variant/50">
          {page.data.map((report, i) => (
            <ReportRow
              key={report.id}
              report={report}
              divider={i !== page.data.length - 1}
            />
          ))}
        </div>
      )}
    </div>
  );
}