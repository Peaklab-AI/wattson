export const config = { runtime: "edge" };

import { exchangeCodeForTokens } from "../../lib/tesla.js";
import { encryptSession } from "../../lib/session.js";

// Tesla redirects here after the user consents. We exchange the code for
// tokens (needs client_secret, so this must happen server-side) and hand
// them to the Wattson app via an encrypted, self-contained session value
// carried through a wattson:// redirect — the tokens themselves never sit
// in a database, and never touch the URL bar in plaintext.
export default async function handler(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const state = url.searchParams.get("state");
  if (!code || !state) {
    return new Response("Missing code or state parameter", { status: 400 });
  }

  const clientId = process.env.TESLA_CLIENT_ID;
  const clientSecret = process.env.TESLA_CLIENT_SECRET;
  const redirectUri = process.env.TESLA_REDIRECT_URI;
  if (!clientId || !clientSecret || !redirectUri) {
    return new Response("Server is missing Tesla OAuth configuration", { status: 500 });
  }

  let tokens;
  try {
    tokens = await exchangeCodeForTokens({ clientId, clientSecret, code, redirectUri });
  } catch (err) {
    return new Response(err instanceof Error ? err.message : "Token exchange failed", { status: 502 });
  }

  const session = await encryptSession(tokens);
  const appURL = `wattson://auth-success?session=${session}`;

  // A raw redirect() here leaves the browser tab blank once the OS hands
  // off to Wattson — the tab itself never closes (browsers block
  // window.close() on tabs that weren't opened via script, which this one
  // wasn't). So instead we render a real page that triggers the handoff
  // itself and leaves something reasonable behind if the tab does stick
  // around, rather than a blank redirect target.
  const html = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta http-equiv="refresh" content="0;url=${appURL}" />
    <title>Wattson — Connected</title>
    <style>
      body {
        margin: 0;
        height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
        background: #12161c;
        color: #f2f3ea;
        font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
        text-align: center;
      }
      .card { max-width: 22rem; padding: 0 1.5rem; }
      h1 { font-size: 1.15rem; margin: 0 0 0.5rem; }
      p { font-size: 0.9rem; opacity: 0.7; margin: 0; }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>You're connected to Wattson</h1>
      <p>You can close this tab and head back to the menu bar.</p>
    </div>
    <script>
      window.location.href = ${JSON.stringify(appURL)};
      setTimeout(() => window.close(), 300);
    </script>
  </body>
</html>`;

  return new Response(html, { status: 200, headers: { "Content-Type": "text/html; charset=utf-8" } });
}
