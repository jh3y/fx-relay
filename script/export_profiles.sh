#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
build_dir="$(xcrun swift build --configuration release --show-bin-path)"
xcrun swiftc -O -I "$build_dir/Modules" script/export_profiles.swift "$build_dir"/FXMicCore.build/*.o -o /tmp/fxmic-export-profiles
/tmp/fxmic-export-profiles "${1:-profiles}"
