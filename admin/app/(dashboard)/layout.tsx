import Link from "next/link";
import { LogoutButton } from "./logout-button";

const NAV = [
  { href: "/", label: "Overview" },
  { href: "/organizer-applications", label: "Organizer applications" },
  { href: "/events", label: "Events" },
  { href: "/reports", label: "Reports" },
];

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="mx-auto flex w-full max-w-6xl flex-1 flex-col px-6">
      <header className="flex items-center justify-between border-b border-outline-variant/50 py-4">
        <div className="flex items-center gap-3">
          <div className="flex h-8 w-8 items-center justify-center rounded-md bg-neon text-sm font-bold text-on-primary">
            EN
          </div>
          <div>
            <p className="text-sm font-semibold leading-none text-on-surface">Event Nu</p>
            <p className="text-xs text-on-surface-variant">Admin console</p>
          </div>
        </div>
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2 rounded-md border border-outline-variant/60 px-3 py-1.5 text-xs text-on-surface-variant">
            <span className="h-2 w-2 rounded-full bg-ok" />
            API connected
          </div>
          <LogoutButton />
        </div>
      </header>
      <div className="flex flex-1 gap-10 py-6">
        <nav className="w-52 shrink-0 space-y-1">
          {NAV.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="block rounded-md px-3 py-2 text-sm text-on-surface-variant hover:bg-surface-container hover:text-on-surface"
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <main className="min-w-0 flex-1">{children}</main>
      </div>
    </div>
  );
}