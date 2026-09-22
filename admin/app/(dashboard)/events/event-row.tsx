import { StatusBadge } from "@/components/status-badge";
import type { AdminEvent } from "@/lib/types";
import { BlockButton, RestoreButton } from "./moderation-buttons";

function fmt(ts: string): string {
  return new Date(ts).toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function EventRow({
  event,
  divider,
}: {
  event: AdminEvent;
  divider: boolean;
}) {
  const blockable = event.moderation_status !== "blocked";
  return (
    <div
      className={`flex flex-wrap items-center justify-between gap-3 bg-surface-container px-5 py-4 ${
        divider ? "border-b border-outline-variant/40" : ""
      }`}
    >
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-3">
          <p className="truncate text-sm font-semibold text-on-surface">{event.title}</p>
          <StatusBadge value={event.status} />
          <StatusBadge value={event.moderation_status} />
        </div>
        <p className="mt-1 truncate text-xs text-on-surface-variant">
          {fmt(event.starts_at)} · {event.price_is_free ? "Free" : event.price_display} ·{" "}
          {event.max_attendees ? `${event.max_attendees} max` : "unlimited"} ·{" "}
          {event.id.slice(0, 8)}
        </p>
        {event.description && (
          <p className="mt-2 line-clamp-1 text-sm text-on-surface-variant">
            {event.description}
          </p>
        )}
      </div>
      <div className="flex shrink-0 items-center gap-2">
        {blockable ? <BlockButton id={event.id} /> : <RestoreButton id={event.id} />}
      </div>
    </div>
  );
}