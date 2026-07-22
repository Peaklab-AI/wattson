# Wattson

**Your Tesla Powerwall, always visible in the Mac menu bar.**

Charge level, solar production, grid import/export, and home consumption. No app to open, no dashboard to refresh. Wattson sits quietly in the menu bar and updates itself.

<p align="center">
  <a href="https://wattson.peaklab.ai"><img alt="Website" src="https://img.shields.io/badge/website-wattson.peaklab.ai-2563EB"></a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2013%2B-black">
  <img alt="Swift" src="https://img.shields.io/badge/swift-6.0-F05138">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-brightgreen"></a>
  <a href="https://discord.gg/BH6DjNwd8"><img alt="Discord" src="https://img.shields.io/badge/chat-Discord-5865F2"></a>
</p>

## Install

```sh
curl -fsSL https://wattson.peaklab.ai/install.sh | bash
```

That downloads the latest build, installs it to `/Applications`, and launches it. No Gatekeeper "unidentified developer" dance, no App Store account: just Terminal and Tesla's own login screen.

## What it shows

| | |
|---|---|
| 🔋 | State of charge, and whether the Powerwall is charging or discharging |
| ☀️ | Live solar production |
| ⚡ | Grid import or export |
| 🏠 | Home consumption |

The menu bar icon gives you the numbers at a glance; click it for a fuller breakdown in the dropdown.

## How it works

Wattson is a native Swift/AppKit menu bar app: no Electron, no background web view, just a small binary polling Tesla's Fleet API on an interval.

Authentication goes through Tesla's own OAuth login, the same one their app uses. A tiny serverless backend ([`apps/landing`](apps/landing)) exists only because Tesla's token exchange requires a `client_secret`, and a `client_secret` can never ship inside a distributable Mac app, so that one step happens server-side, and the resulting tokens are relayed straight back to the app and never stored anywhere. From then on, Wattson talks to Tesla directly:

```
┌─────────────┐   1. OAuth login    ┌────────────────┐
│  Wattson.app │ ───────────────────▶│  auth.tesla.com│
│ (menu bar)   │◀─────────────────── │                │
└──────┬───────┘   2. code            └────────────────┘
       │
       │ 3. code → tokens (needs client_secret)
       ▼
┌─────────────────────┐
│ wattson.peaklab.ai   │  serverless, stateless,
│ /oauth/callback      │  nothing persisted server-side
└──────┬───────────────┘
       │ 4. tokens, relayed once via wattson:// redirect
       ▼
┌─────────────────┐   5. poll every ~30s   ┌───────────────────┐
│ macOS Keychain   │───────────────────────▶│ Tesla Fleet API    │
│ (refresh token)  │◀───────────────────────│ (live_status, etc) │
└──────────────────┘                        └────────────────────┘
```

Your access token lives in the macOS Keychain. It never touches our servers, a database, or a log file. See [`CredentialStore.swift`](apps/macos/Sources/Wattson/CredentialStore.swift).

## Project structure

```
apps/
  macos/     Native Swift/AppKit menu bar app (SwiftPM)
  landing/   Marketing site + OAuth backend (Vite + Vercel Functions)
```

Two independent halves of one monorepo: `apps/macos` is the app you run, `apps/landing` is the website plus the sliver of serverless glue the OAuth handshake needs.

## Building from source

**Requirements:** macOS 13+, Swift 6, [pnpm](https://pnpm.io), and your own [Tesla developer app](https://developer.tesla.com/) (Wattson talks to Tesla's Fleet API, which requires registering a client and verifying a domain, so you can't borrow ours).

```sh
git clone https://github.com/paulballesty/wattson.git
cd wattson
pnpm install
```

**macOS app**: for local development, point it at your own Tesla client id via an env var:

```sh
export WATTSON_TESLA_CLIENT_ID="your-tesla-client-id"
cd apps/macos
swift run
```

For a distributable `.app`, bake the client id into the binary at build time instead (see [`scripts/build-app.sh`](apps/macos/scripts/build-app.sh)):

```sh
cd apps/macos
scripts/release.sh --client-id "your-tesla-client-id" --sign "Developer ID Application: Your Name (TEAMID)"
```

**Landing page / OAuth backend:**

```sh
pnpm --filter @wattson/landing dev
```

The backend needs `TESLA_CLIENT_ID`, `TESLA_CLIENT_SECRET`, `TESLA_REDIRECT_URI`, and `OAUTH_SESSION_KEY` set. See [`apps/landing/api/oauth/callback.ts`](apps/landing/api/oauth/callback.ts) and [`apps/landing/lib/session.ts`](apps/landing/lib/session.ts) for what each one does.

## Contributing

Issues and PRs welcome. For anything bigger than a small fix, open an issue first so we're aligned on approach before you sink time into it.

## Disclaimer

Wattson is an independent project and is not affiliated with, endorsed by, or sponsored by Tesla, Inc.

## License

[MIT](LICENSE). See the license file for the full text.
