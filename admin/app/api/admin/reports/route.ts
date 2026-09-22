import { proxy } from "@/lib/proxy";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export function GET(request: Request) {
  return proxy("/api/v1/admin/reports", request);
}