import { listOrganizerApplications } from "@/lib/admin";
import { ApplicationRow } from "./application-row";

export const dynamic = "force-dynamic";

export default async function ApplicationsPage() {
  const page = await listOrganizerApplications({ page: 1, limit: 50 });
  const pending = page.data.filter((a) => a.status === "pending");

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-on-surface">Organizer applications</h1>
        <p className="mt-1 text-sm text-on-surface-variant">
          {page.pagination.total} total
          {pending.length > 0 && ` · ${pending.length} awaiting review`}
        </p>
      </div>

      {page.data.length === 0 ? (
        <p className="rounded-lg border border-dashed border-outline-variant/60 px-4 py-8 text-center text-sm text-on-surface-variant">
          No applications yet.
        </p>
      ) : (
        <div className="overflow-hidden rounded-lg border border-outline-variant/50">
          {page.data.map((app, i) => (
            <ApplicationRow
              key={app.id}
              app={app}
              divider={i !== page.data.length - 1}
            />
          ))}
        </div>
      )}
    </div>
  );
}