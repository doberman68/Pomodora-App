#!/usr/bin/env bash
# Generates PomodoroTimer.xcodeproj from project.yml and opens it in Xcode.
#   ./generate.sh              uses the saved Team ID (or none; pick it in Xcode)
#   ./generate.sh ABCDE12345   saves your Apple Developer Team ID for signing
set -euo pipefail
cd "$(dirname "$0")"

if [[ -n "${1:-}" ]]; then
    echo "$1" > .team-id
fi
export TEAM_ID="$(cat .team-id 2>/dev/null || true)"

if ! command -v xcodegen >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        echo "==> Installing XcodeGen"
        brew install xcodegen
    else
        echo "XcodeGen is required. Install Homebrew (https://brew.sh) and re-run,"
        echo "or download XcodeGen from https://github.com/yonaskolb/XcodeGen/releases"
        exit 1
    fi
fi

xcodegen generate
open PomodoroTimer.xcodeproj
