import { listEvents } from "@/lib/admin";
import { EventRow } from "./event-row";

export const dynamic = "force-dynamic";

export default async function EventsPage() {
  const page = await listEvents({ page: 1, limit: 50 });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-on-surface">Events</h1>
        <p className="mt-1 text-sm text-on-surface-variant">
          {page.pagination.total} events · every lifecycle and moderation status
        </p>
      </div>

      {page.data.length === 0 ? (
        <p className="rounded-lg border border-dashed border-outline-variant/60 px-4 py-8 text-center text-sm text-on-surface-variant">
          No events.
        </p>
      ) : (
        <div className="overflow-hidden rounded-lg border border-outline-variant/50">
          {page.data.map((event, i) => (
            <EventRow
              key={event.id}
              event={event}
              divider={i !== page.data.length - 1}
            />
          ))}
        </div>
      )}
    </div>
  );
}