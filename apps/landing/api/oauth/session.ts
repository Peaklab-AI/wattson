export const config = { runtime: "edge" };

import { decryptSession } from "../../lib/session.js";
import type { TeslaTokenResponse } from "../../lib/tesla.js";

// Called exactly once by the Wattson app right after the wattson://
// auth-success handoff. Decrypts the session value from callback.ts and
// returns the token pair — there's nothing stored server-side to look up.
export default async function handler(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const session = url.searchParams.get("session");
  if (!session) {
    return new Response("Missing session parameter", { status: 400 });
  }

  try {
    const tokens = await decryptSession<TeslaTokenResponse>(session);
    return new Response(JSON.stringify(tokens), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch {
    return new Response("Session not found, expired, or invalid", { status: 404 });
  }
}
