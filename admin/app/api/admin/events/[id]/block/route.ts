import { proxyAction } from "@/lib/action";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  return proxyAction(`/api/v1/admin/events/${id}/block`, {});
}