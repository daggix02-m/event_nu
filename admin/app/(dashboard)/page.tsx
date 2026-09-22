import Link from "next/link";
import { listEvents, listOrganizerApplications, listReports } from "@/lib/admin";

export const dynamic = "force-dynamic";

export default async function OverviewPage() {
  const [apps, events, reports] = await Promise.all([
    listOrganizerApplications({ page: 1, limit: 1 }).catch(() => null),
    listEvents({ page: 1, limit: 1 }).catch(() => null),
    listReports({ page: 1, limit: 1 }).catch(() => null),
  ]);

  const cards = [
    {
      href: "/organizer-applications",
      label: "Organizer applications",
      value: apps?.pagination.total ?? "—",
      hint: apps?.pagination.total === 0 ? "No applications" : "Awaiting review",
    },
    {
      href: "/events",
      label: "Events",
      value: events?.pagination.total ?? "—",
      hint: "All lifecycle statuses",
    },
    {
      href: "/reports",
      label: "Reports",
      value: reports?.pagination.total ?? "—",
      hint: "Open moderation items",
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-on-surface">Overview</h1>
        <p className="mt-1 text-sm text-on-surface-variant">
          Moderation queue at a glance.
        </p>
      </div>
      <div className="grid gap-4 sm:grid-cols-3">
        {cards.map((c) => (
          <Link
            key={c.href}
            href={c.href}
            className="rounded-lg border border-outline-variant/50 bg-surface-container px-5 py-4 transition-colors hover:border-neon"
          >
            <p className="text-xs uppercase tracking-wide text-on-surface-variant">
              {c.label}
            </p>
            <p className="mt-2 text-3xl font-semibold text-on-surface">{c.value}</p>
            <p className="mt-1 text-xs text-on-surface-variant">{c.hint}</p>
          </Link>
        ))}
      </div>
    </div>
  );
}