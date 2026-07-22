#!/usr/bin/env bash
# Packages the ad-hoc-signed .app bundle into a .zip and drops it into the
# landing page's public/ folder, so it deploys to wattson.peaklab.ai/downloads
# alongside the site itself — no Apple Developer ID means no notarization,
# and the source repo is private, so GitHub Releases isn't an option either
# (its download URLs require auth on a private repo). Downloaders will need
# to bypass Gatekeeper once via System Settings > Privacy & Security >
# "Open Anyway" (documented on the landing page next to the download button).
#
# Usage: scripts/release.sh [--client-id TESLA_CLIENT_ID] [--sign "Developer ID Application: Your Name (TEAMID)"]
# Arguments are forwarded to build-app.sh.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Wattson"
APP_BUNDLE="release/${APP_NAME}.app"
ZIP_PATH="release/${APP_NAME}.zip"
LANDING_DOWNLOAD_DIR="../landing/public/downloads"

./scripts/build-app.sh "$@"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${APP_BUNDLE}/Contents/Info.plist")

echo "Zipping ${APP_BUNDLE} (v${VERSION})..."
rm -f "${ZIP_PATH}"
# ditto (not `zip`) preserves the bundle structure and extended attributes
# correctly — plain `zip` can mangle .app bundles.
ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

mkdir -p "${LANDING_DOWNLOAD_DIR}"
cp "${ZIP_PATH}" "${LANDING_DOWNLOAD_DIR}/${APP_NAME}.zip"

echo "Built ${ZIP_PATH} (v${VERSION})"
echo "Copied to ${LANDING_DOWNLOAD_DIR}/${APP_NAME}.zip — commit and push apps/landing to publish it at wattson.peaklab.ai/downloads/Wattson.zip."
