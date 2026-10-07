#!/usr/bin/env bash
# Purpose: Exact-source Swift6 XHTML contracts with bounded execution and provenance.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d -t semantic-xhtml-contract.XXXXXX)"
EVIDENCE="${XHTML_EVIDENCE_DIR:-$ROOT/evidence/xhtml}"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/Sources/vreader" "$WORK/Tests/vreaderTests" "$EVIDENCE"
for area in EPUB XML Package XHTML; do
  cp "$ROOT"/vreader/Services/Semantic/"$area"/*.swift "$WORK/Sources/vreader/"
done
cp "$ROOT"/vreader/Models/Semantic/*.swift "$WORK/Sources/vreader/"
cp "$ROOT"/vreaderTests/Services/Semantic/XHTML/*.swift "$WORK/Tests/vreaderTests/"
for helper in EPUBSemanticZIPFixture EPUBPackageFixture SemanticXMLProbe; do
  cp "$ROOT/vreaderTests/Helpers/$helper.swift" "$WORK/Tests/vreaderTests/"
done
git -C "$ROOT" rev-parse HEAD > "$EVIDENCE/input-commit.txt"
xcrun swift --version > "$EVIDENCE/swift-version.txt"
xcodebuild -version > "$EVIDENCE/xcode-version.txt"
cat > "$WORK/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "SemanticXHTMLContract", platforms: [.macOS(.v15)],
    targets: [.target(name: "vreader", linkerSettings: [.linkedLibrary("z")]),
              .testTarget(name: "vreaderTests", dependencies: ["vreader"])], swiftLanguageModes: [.v6])
SWIFT
python3 - "$ROOT" "$WORK" "$EVIDENCE" <<'PY'
from pathlib import Path
import hashlib, json, os, re, signal, subprocess, sys
root, work, evidence = map(Path, sys.argv[1:])
files = list((root/'vreader/Services/Semantic').rglob('*.swift')) + list((root/'vreader/Models/Semantic').glob('*.swift'))
files += list((root/'vreaderTests/Services/Semantic/XHTML').glob('*.swift'))
files += [root/'vreaderTests/Helpers'/f'{h}.swift' for h in ['EPUBSemanticZIPFixture','EPUBPackageFixture','SemanticXMLProbe']]
manifest = {str(p.relative_to(root)): dict(bytes=p.stat().st_size,
    sha256=hashlib.sha256(p.read_bytes()).hexdigest(),
    git_blob_sha=subprocess.check_output(['git','hash-object',str(p)],text=True).strip()) for p in sorted(files)}
(evidence/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
command = ['swift','test','--package-path',str(work),'-Xswiftc','-strict-concurrency=complete']
with (evidence/'contract.log').open('w') as log:
    process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    try: status = process.wait(timeout=300)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL); process.wait(); status=124
(evidence/'command-status.txt').write_text(str(status)+'\n')
text = (evidence/'contract.log').read_text(errors='replace')
print(text)
if status: raise SystemExit(status)
counts = re.findall(r'Test run with (\d+) tests.*passed',text)
if not counts or int(counts[-1]) <= 0: raise SystemExit('No positive Swift Testing count')
if re.search(r'\bskipped\b',text,re.I): raise SystemExit('Skipped execution is not acceptance')
for suite in ['Semantic XHTML structure','Semantic XHTML safety','Semantic XHTML integration']:
    if not re.search(r'Suite "'+re.escape(suite)+r'" passed',text): raise SystemExit('Missing suite: '+suite)
print('XHTML-CONTRACT RESULT: SUCCEEDED; tests='+counts[-1])
PY
