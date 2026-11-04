#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Use the same toolchain and optimized core artifacts as the tests.
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
build_dir="$(xcrun swift build --configuration release --show-bin-path)"
preview_sources=()
while IFS= read -r file; do preview_sources+=("$file"); done < <(rg --files Sources/FXMicBridge | sort | sed '/\/App\//d')
xcrun swiftc -O -parse-as-library -swift-version 5 -target arm64-apple-macosx15.0 \
  -I "$build_dir/Modules" "${preview_sources[@]}" script/render_ui.swift \
  "$build_dir"/FXMicCore.build/*.o -o /tmp/fxmic-ui-render
/tmp/fxmic-ui-render "${1:-docs/previews/v0.5.0}"
