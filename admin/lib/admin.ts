import { headers } from "next/headers";
import type {
  AdminEvent,
  AdminOrganizerApplication,
  AdminReport,
  Page,
} from "./types";

export interface ListQuery {
  status?: string;
  moderation_status?: string;
  page?: number;
  limit?: number;
}

/**
 * Fetches the admin console's own API route (the BFF). The proxy route handler
 * owns cookie refresh + backend auth, so reads never set cookies from a Server
 * Component render (Next forbids it). The host is resolved from the forwarded
 * headers so it works locally and behind a reverse proxy.
 */
async function adminFetch<T>(path: string): Promise<T> {
  const h = await headers();
  const host = h.get("x-forwarded-host") ?? h.get("host") ?? "localhost:3000";
  const proto = h.get("x-forwarded-proto") ?? "http";
  const res = await fetch(`${proto}://${host}${path}`, {
    cache: "no-store",
    signal: AbortSignal.timeout(20_000),
  });
  const json = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(
      (json as { error?: { message?: string } })?.error?.message ?? `request failed (${res.status})`,
    );
  }
  return json as T;
}

function qs(params: ListQuery): string {
  const search = new URLSearchParams();
  if (params.status) search.set("status", params.status);
  if (params.moderation_status) search.set("moderation_status", params.moderation_status);
  if (params.page) search.set("page", String(params.page));
  if (params.limit) search.set("limit", String(params.limit));
  const s = search.toString();
  return s ? `?${s}` : "";
}

export function listOrganizerApplications(
  params: ListQuery = {},
): Promise<Page<AdminOrganizerApplication>> {
  return adminFetch(`/api/admin/organizer-applications${qs(params)}`);
}

export function listEvents(params: ListQuery = {}): Promise<Page<AdminEvent>> {
  return adminFetch(`/api/admin/events${qs(params)}`);
}

export function listReports(params: ListQuery = {}): Promise<Page<AdminReport>> {
  return adminFetch(`/api/admin/reports${qs(params)}`);
}