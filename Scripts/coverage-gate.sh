#!/usr/bin/env bash
#
# 100% line-coverage gate for Open Caffein's logic files.
# Regenerates the project, runs the test suite with coverage, and fails if any
# non-excluded source file under OpenCaffein/ is below 100% (see Scripts/coverage_check.py).
#
# Usage:  Scripts/coverage-gate.sh
set -euo pipefail

cd "$(dirname "$0")/.."
REPO="$(pwd)"
RESULT="$(mktemp -d)/coverage.xcresult"

echo "▸ Generating project + running tests with coverage…"
xcodegen generate >/dev/null
xcodebuild -project OpenCaffein.xcodeproj -scheme OpenCaffein \
    -destination 'platform=macOS' -enableCodeCoverage YES \
    -resultBundlePath "$RESULT" test >/dev/null

xcrun xccov view --report --json "$RESULT" | REPO="$REPO" python3 Scripts/coverage_check.py
