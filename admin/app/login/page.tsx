import { redirect } from "next/navigation";
import { callBackend } from "@/lib/backend";
import { readPair } from "@/lib/session";
import { LoginForm } from "./login-form";

export const dynamic = "force-dynamic";

export default async function LoginPage() {
  const pair = await readPair();
  if (pair.access) {
    try {
      const { json } = await callBackend("/api/v1/users/me", { pair });
      const user = (json as { data: { role?: string } }).data;
      if (user.role === "admin") redirect("/");
    } catch {
      // expired/stale access — fall through to the login form.
    }
  }
  return <LoginForm />;
}