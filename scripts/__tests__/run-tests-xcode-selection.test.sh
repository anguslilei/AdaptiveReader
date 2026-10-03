#!/usr/bin/env bash
# Bug #376: the test wrapper must use the compiler selected for the build.
# Stub xcodebuild; never launches a real simulator/test or kills a build daemon.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat > "$TMP/bin/xcodebuild" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$DEVELOPER_DIR" > "$XCODE_SELECTION_LOG"
echo 'TEST SUCCEEDED'
STUB
chmod +x "$TMP/bin/xcodebuild"
# A delayed stub must never let the watchdog kill a real build daemon.
cat > "$TMP/bin/pkill" <<'STUB'
#!/usr/bin/env bash
case "$*" in *SWBBuildService*) exit 0 ;; esac
exec /usr/bin/pkill "$@"
STUB
chmod +x "$TMP/bin/pkill"
export XCODE_SELECTION_LOG="$TMP/selected.txt"
export PATH="$TMP/bin:$PATH"
export TEST_UDID="FAKE-UDID"
export TIMEOUT_SECS=2
fallback='/Applications/Xcode.app/Contents/Developer'
selected='/Applications/Xcode_26.3.app/Contents/Developer'

check() {
    local expected="$1"
    if [[ "$(cat "$XCODE_SELECTION_LOG")" != "$expected" ]]; then
        echo "FAIL: wrapper selected $(cat "$XCODE_SELECTION_LOG"), expected $expected"
        exit 1
    fi
}
DEVELOPER_DIR="$selected" bash "$HERE/../run-tests.sh" vreaderTests/Fake > "$TMP/result.txt"
check "$selected"
env -u DEVELOPER_DIR bash "$HERE/../run-tests.sh" vreaderTests/Fake > "$TMP/result.txt"
check "$fallback"
DEVELOPER_DIR='' bash "$HERE/../run-tests.sh" vreaderTests/Fake > "$TMP/result.txt"
check "$fallback"
echo 'PASS: selected, unset and empty compiler environment cases'
