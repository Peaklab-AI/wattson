/**
 * Stateless replacement for the KV-backed session handoff the Cloudflare
 * version used. Instead of storing tokens server-side and returning a
 * lookup id, the token payload is AES-GCM encrypted (key held only in the
 * OAUTH_SESSION_KEY env var) and the ciphertext itself becomes the "session"
 * value carried through the wattson://auth-success redirect. No database,
 * no KV — Vercel Functions only.
 *
 * Trade-off vs. the old KV design: claiming a session no longer invalidates
 * it server-side (there's no state to delete), so a short expiry embedded
 * in the ciphertext is the only replay guard. The value only ever traverses
 * the user's own machine (browser -> custom URL scheme -> this endpoint),
 * so the exposure window is already narrow.
 */

const ALGO = "AES-GCM";
const IV_LENGTH = 12;
const MAX_AGE_MS = 5 * 60 * 1000;

// TS's DOM lib types BufferSource as ArrayBufferView<ArrayBuffer>, which
// plain Uint8Arrays don't structurally satisfy even though they work fine
// at runtime — cast at the Web Crypto boundary rather than fight the types.
function asBufferSource(bytes: Uint8Array): BufferSource {
  return bytes as unknown as BufferSource;
}

async function getKey(): Promise<CryptoKey> {
  const raw = process.env.OAUTH_SESSION_KEY;
  if (!raw) {
    throw new Error("OAUTH_SESSION_KEY is not set");
  }
  return crypto.subtle.importKey("raw", asBufferSource(base64UrlToBytes(raw)), ALGO, false, [
    "encrypt",
    "decrypt",
  ]);
}

export async function encryptSession(payload: unknown): Promise<string> {
  const key = await getKey();
  const iv = crypto.getRandomValues(new Uint8Array(IV_LENGTH));
  const plaintext = new TextEncoder().encode(JSON.stringify({ payload, issuedAt: Date.now() }));
  const ciphertext = new Uint8Array(
    await crypto.subtle.encrypt({ name: ALGO, iv: asBufferSource(iv) }, key, asBufferSource(plaintext)),
  );

  const combined = new Uint8Array(iv.length + ciphertext.length);
  combined.set(iv, 0);
  combined.set(ciphertext, iv.length);
  return bytesToBase64Url(combined);
}

export async function decryptSession<T>(token: string): Promise<T> {
  const key = await getKey();
  const combined = base64UrlToBytes(token);
  const iv = combined.slice(0, IV_LENGTH);
  const ciphertext = combined.slice(IV_LENGTH);

  const plaintextBytes = new Uint8Array(
    await crypto.subtle.decrypt({ name: ALGO, iv: asBufferSource(iv) }, key, asBufferSource(ciphertext)),
  );
  const { payload, issuedAt } = JSON.parse(new TextDecoder().decode(plaintextBytes)) as {
    payload: T;
    issuedAt: number;
  };

  if (Date.now() - issuedAt > MAX_AGE_MS) {
    throw new Error("Session expired");
  }
  return payload;
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlToBytes(value: string): Uint8Array {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/");
  const pad = padded.length % 4 === 0 ? "" : "=".repeat(4 - (padded.length % 4));
  const binary = atob(padded + pad);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}
