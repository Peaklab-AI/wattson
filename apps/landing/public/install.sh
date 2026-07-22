#!/usr/bin/env bash
# Installs Wattson without hitting Gatekeeper's "unidentified developer"
# block. Safari/Chrome tag anything they download with the
# com.apple.quarantine extended attribute, which is what triggers that
# warning on first launch — curl doesn't set it, so an app installed this
# way skips that check entirely instead of needing the System Settings >
# "Open Anyway" bypass that a browser download requires.
#
# Usage: curl -fsSL https://wattson.peaklab.ai/install.sh | bash
set -euo pipefail

APP_NAME="Wattson"
DOWNLOAD_URL="https://wattson.peaklab.ai/downloads/Wattson.zip"
INSTALL_DIR="/Applications"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

if [[ "$(uname)" != "Darwin" ]]; then
  echo "Wattson is a macOS app — this installer only works on a Mac." >&2
  exit 1
fi

echo "Downloading ${APP_NAME}..."
curl -fsSL "${DOWNLOAD_URL}" -o "${TMP_DIR}/${APP_NAME}.zip"

echo "Unpacking..."
ditto -x -k "${TMP_DIR}/${APP_NAME}.zip" "${TMP_DIR}"

if [[ ! -d "${TMP_DIR}/${APP_NAME}.app" ]]; then
  echo "Something went wrong — ${APP_NAME}.app wasn't found after unzipping." >&2
  exit 1
fi

if pgrep -x "${APP_NAME}" > /dev/null 2>&1; then
  echo "Quitting the running copy of ${APP_NAME}..."
  osascript -e "tell application \"${APP_NAME}\" to quit" > /dev/null 2>&1 || true
  sleep 1
fi

echo "Installing to ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
if ! mv "${TMP_DIR}/${APP_NAME}.app" "${INSTALL_DIR}/" 2>/dev/null; then
  echo "Couldn't write to ${INSTALL_DIR} — installing to ~/Applications instead..."
  INSTALL_DIR="${HOME}/Applications"
  mkdir -p "${INSTALL_DIR}"
  rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
  mv "${TMP_DIR}/${APP_NAME}.app" "${INSTALL_DIR}/"
fi

# Belt-and-suspenders: strip any quarantine attribute that might have been
# set (e.g. by an intermediate tool), so a re-run never re-triggers Gatekeeper.
xattr -dr com.apple.quarantine "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true

echo "Launching ${APP_NAME}..."
open "${INSTALL_DIR}/${APP_NAME}.app"

echo "${APP_NAME} is installed in ${INSTALL_DIR} — look for it in your menu bar."
