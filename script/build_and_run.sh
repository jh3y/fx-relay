#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="FXMicBridge"
BUNDLE_ID="com.jhey.fxmicbridge"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/FX Relay.app"
# The continuously running audio path needs compiler optimization for everyday use.
# Keep an unoptimized build available for source-level debugging.
DEFAULT_CONFIGURATION="release"
if [[ "$MODE" == "--debug" ]]; then DEFAULT_CONFIGURATION="debug"; fi
CONFIGURATION="${FXMIC_BUILD_CONFIGURATION:-$DEFAULT_CONFIGURATION}"
BUILD_JOBS="${FXMIC_BUILD_JOBS:-2}"
if ! [[ "$BUILD_JOBS" =~ ^[1-9][0-9]*$ ]]; then
  echo "FXMIC_BUILD_JOBS must be a positive integer." >&2
  exit 2
fi
cd "$ROOT_DIR"
# Keep Xcode's test toolchain and the Command Line Tools from reusing incompatible modules.
TOOLCHAIN_ID="$(xcrun swift --version | shasum -a 256 | cut -c 1-12)"
SCRATCH_PATH="$ROOT_DIR/.build/app-$TOOLCHAIN_ID"

case "$MODE" in
  run|--build-only|--debug|--logs|--telemetry|--verify) ;;
  *) echo "usage: $0 [--build-only|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac

# Match only this executable. ps remains usable on hosts where pgrep's process service fails.
running_pids() {
  local processes
  processes="$(ps -axo pid=,comm=)" || return 2
  awk '$1 ~ /^[0-9]+$/ && $NF ~ /(^|\/)FXMicBridge$/ {print $1}' <<<"$processes"
}

# SIGTERM is handled by the app so a pending test releases Space and saves diagnostics.
APP_PIDS="$(running_pids)" || { echo "Cannot inspect running apps; no bundle was replaced." >&2; exit 1; }
if [[ -n "$APP_PIDS" ]]; then
  while IFS= read -r pid; do kill -TERM "$pid"; done <<<"$APP_PIDS"
  for attempt in 1 2 3 4 5; do
    APP_PIDS="$(running_pids)" || exit 1
    if [[ -z "$APP_PIDS" ]]; then break; fi
    sleep 1
  done
  APP_PIDS="$(running_pids)" || exit 1
  if [[ -n "$APP_PIDS" ]]; then
    echo "The running app did not quit. Quit FX Relay before rebuilding." >&2
    exit 1
  fi
fi

xcrun swift build --jobs "$BUILD_JOBS" --scratch-path "$SCRATCH_PATH" --configuration "$CONFIGURATION"
BUILD_DIR="$(xcrun swift build --scratch-path "$SCRATCH_PATH" --configuration "$CONFIGURATION" --show-bin-path)"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
mkdir -p "$APP_BUNDLE/Contents/Resources/CuePacks"
for version in 1 2 3; do
  /usr/bin/ditto "$ROOT_DIR/hardware/agent-cues-v$version" "$APP_BUNDLE/Contents/Resources/CuePacks/agent-cues-v$version"
done
/usr/bin/codesign --force --sign "${FXMIC_SIGNING_IDENTITY:--}" --options runtime \
  --identifier "$BUNDLE_ID" --entitlements "$ROOT_DIR/Resources/FXMicBridge.entitlements" "$APP_BUNDLE"
/usr/bin/codesign --verify --strict "$APP_BUNDLE"

case "$MODE" in
  --build-only) echo "Built: $APP_BUNDLE" ;;
  --debug)
    /usr/bin/open "$APP_BUNDLE"
    exec lldb -n "$APP_NAME" ;;
  --logs|--telemetry)
    /usr/bin/open "$APP_BUNDLE"
    exec /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\"" ;;
  --verify)
    /usr/bin/open "$APP_BUNDLE"
    sleep 2
    APP_PIDS="$(running_pids)" || exit 1
    [[ -n "$APP_PIDS" ]]
    echo "FX Relay is running in the menu bar." ;;
  run) /usr/bin/open "$APP_BUNDLE" ;;
esac
