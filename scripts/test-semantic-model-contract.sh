#!/usr/bin/env bash
# Purpose: Actual Swift6 execution of the exact semantic value sources and tests.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d -t semantic-model-contract.XXXXXX)"
EVIDENCE="$ROOT/evidence"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/Sources/vreader" "$WORK/Tests/vreaderTests" "$EVIDENCE"
cp "$ROOT"/vreader/Models/Semantic/*.swift "$WORK/Sources/vreader/"
cp "$ROOT"/vreaderTests/Models/Semantic/*.swift "$WORK/Tests/vreaderTests/"
git -C "$ROOT" rev-parse HEAD > "$EVIDENCE/input-commit.txt"
xcrun swift --version > "$EVIDENCE/swift-version.txt"
xcodebuild -version > "$EVIDENCE/xcode-version.txt"
cat > "$WORK/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "SemanticModelContract", platforms: [.macOS(.v15)],
    targets: [.target(name: "vreader"), .testTarget(name: "vreaderTests", dependencies: ["vreader"])],
    swiftLanguageModes: [.v6])
SWIFT
set +e
swift test --package-path "$WORK" -Xswiftc -strict-concurrency=complete 2>&1 | tee "$EVIDENCE/contract.log"
status=${PIPESTATUS[0]}
set -e
printf '%s\n' "$status" > "$EVIDENCE/command-status.txt"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import hashlib, json, subprocess, sys
root = Path(sys.argv[1])
files = sorted(list((root / 'vreader/Models/Semantic').glob('*.swift')) +
               list((root / 'vreaderTests/Models/Semantic').glob('*.swift')))
if len(files) != 12: raise SystemExit('Expected exactly nine models and three test files')
facts = {str(p.relative_to(root)): {
    'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest(),
    'git_blob_sha': subprocess.check_output(['git', 'hash-object', str(p)], text=True).strip()
} for p in files}
(root / 'evidence/source-manifest.json').write_text(json.dumps(facts, indent=2) + '\n')
PY
if [ "$status" -ne 0 ]; then exit "$status"; fi
python3 - "$EVIDENCE" <<'PY'
from pathlib import Path
import re, sys
root = Path(sys.argv[1])
log = (root / 'contract.log').read_text()
counts = re.findall(r'Test run with (\d+) tests.*passed', log)
if not counts or int(counts[-1]) <= 0:
    raise SystemExit('Missing actual positive Swift Testing execution')
for suite in ['Semantic identity canonical bytes', 'Semantic logical source anchors', 'Semantic model validated decoding']:
    if not re.search(r'Suite "' + re.escape(suite) + r'" passed', log):
        raise SystemExit('Missing passing suite: ' + suite)
print('Executed semantic model tests:', counts[-1], 'all three suites passed')
PY
