import { proxyAction } from "@/lib/action";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const body = await request.json().catch(() => ({}));
  return proxyAction(`/api/v1/admin/organizer-applications/${id}/reject`, body);
}