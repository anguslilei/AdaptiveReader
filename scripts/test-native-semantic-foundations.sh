#!/usr/bin/env bash
# Purpose: Sequential native lanes avoid synchronous observation-gate pool contention.
set -euo pipefail
mkdir -p preparation
xcodebuild -version > preparation/test-xcode-version.txt

run_lane() {
  local lane="$1"
  shift
  python3 -c 'import time; print(time.time())' > "preparation/$lane-test-start.txt"
  set +e
  bash scripts/run-tests.sh "$@" > "preparation/$lane-test-wrapper.log" 2>&1
  local status=$?
  set -e
  printf '%s\n' "$status" > "preparation/$lane-test-command-status.txt"
  cat "preparation/$lane-test-wrapper.log"
  python3 - "$lane" <<'PY'
from pathlib import Path
import re, shutil, sys
lane = sys.argv[1]
wrapper = Path(f'preparation/{lane}-test-wrapper.log').read_text()
first = wrapper.splitlines()[0] if wrapper else ''
m = re.search(r' log=(/var/folders/[^/]+/[^/]+/T/run-tests\.[^\s]+)$', first)
if m and Path(m[1]).is_file():
    shutil.copyfile(m[1], f'preparation/{lane}-test-full.log')
    for line in Path(m[1]).read_text(errors='replace').splitlines():
        if any(s in line for s in ['✘', 'Expectation failed', 'Issue recorded', 'error:']):
            print(line)
PY
  if [ "$status" -ne 0 ]; then return "$status"; fi
  python3 - "$lane" <<'PY'
from pathlib import Path
import sys
lane = sys.argv[1]
start = float(Path(f'preparation/{lane}-test-start.txt').read_text())
results = [p for p in (Path.home() / 'Library/Developer/Xcode/DerivedData').glob('*/Logs/Test/*.xcresult') if p.stat().st_mtime >= start and (p / 'Info.plist').is_file()]
if not results:
    raise SystemExit('No completed result bundle from lane: ' + lane)
Path(f'preparation/{lane}-test-result-path.txt').write_text(str(max(results, key=lambda p: p.stat().st_mtime)))
PY
  local result_path
  result_path=$(cat "preparation/$lane-test-result-path.txt")
  xcrun xcresulttool get test-results summary --path "$result_path" > "preparation/$lane-test-summary.json"
  xcrun xcresulttool get test-results tests --path "$result_path" > "preparation/$lane-test-tree.json"
  python3 - "$lane" <<'PY'
from pathlib import Path
import json, re, sys
lane = sys.argv[1]
d = json.loads(Path(f'preparation/{lane}-test-summary.json').read_text())
counts = [d.get(k) for k in ['totalTestCount', 'passedTests', 'failedTests', 'skippedTests']]
if any(type(v) is not int for v in counts) or counts[0] <= 0 or counts[0] != counts[1] or counts[2:] != [0, 0]:
    raise SystemExit('Expected complete executed passing counts: ' + lane)
if Path(f'preparation/{lane}-test-command-status.txt').read_text().strip() != '0':
    raise SystemExit('Original test command did not succeed')
wrapper = Path(f'preparation/{lane}-test-wrapper.log').read_text()
full = Path(f'preparation/{lane}-test-full.log').read_text(errors='replace')
if 'RUN-TESTS RESULT: SUCCEEDED' not in wrapper or not re.search(r'Test run with [1-9]\d* tests.*passed', full):
    raise SystemExit('Missing successful wrapper/full Swift Testing log')
udid = Path('preparation/test-udid.txt').read_text().strip()
devices = [v for v in d.get('devicesAndConfigurations', []) if v.get('device', {}).get('deviceId') == udid]
if len(devices) != 1 or devices[0].get('failedTests') != 0 or devices[0].get('skippedTests') != 0:
    raise SystemExit('Unexpected test device or device counts')
def nodes(v):
    if isinstance(v, dict):
        yield v
        for child in v.values(): yield from nodes(child)
    elif isinstance(v, list):
        for child in v: yield from nodes(child)
aliases = {
    'base': [('EPUBSemanticResourceReaderTests', 'Semantic EPUB resources'),
             ('EPUBSourceZIPValidationTests', 'Semantic EPUB ZIP grammar'),
             ('EPUBSourceBudgetTests', 'Semantic EPUB budgets and cancellation'),
             ('SemanticXMLParserTests', 'Semantic XML logical structure'),
             ('SemanticXMLSafetyTests', 'Semantic XML safety and budgets'),
             ('SemanticXMLCancellationTests', 'Semantic XML cancellation')],
    'package': [('EPUBPackageReferenceTests', 'EPUB package local references'),
                ('EPUBPackageDecoderTests', 'EPUB package manifest and spine'),
                ('EPUBPackageLoaderTests', 'EPUB package source lifecycle')],
    'model': [('SemanticIdentityTests', 'Semantic identity canonical bytes'),
              ('SemanticSourceAnchorTests', 'Semantic logical source anchors'),
              ('SemanticModelCodableTests', 'Semantic model validated decoding')],
    'xhtml': [('SemanticXHTMLStructureTests', 'Semantic XHTML structure'),
              ('SemanticXHTMLSafetyTests', 'Semantic XHTML safety'),
              ('SemanticXHTMLIntegrationTests', 'Semantic XHTML integration')]
}[lane]
tree = json.loads(Path(f'preparation/{lane}-test-tree.json').read_text())
for names in aliases:
    found = [n for n in nodes(tree) if n.get('nodeType') == 'Test Suite' and any(name in str(n.get('name', '')) or name in str(n.get('nodeIdentifier', '')) for name in names)]
    if not any(n.get('result') == 'Passed' for n in found):
        raise SystemExit('Missing executed passing suite: ' + names[0])
print('Native lane:', lane, 'tests:', counts[0], 'passed:', counts[1], 'semantic suites:', len(aliases))
PY
}

# Complete/validate the old lane before starting the next invocation on this UDID.
run_lane base \
  vreaderTests/EPUBReaderViewModelOpenTests \
  vreaderTests/EPUBReaderViewModelCloseTests \
  vreaderTests/EPUBReaderViewModelNavigationTests \
  vreaderTests/EPUBReaderViewModelLifecycleTests \
  vreaderTests/EPUBReaderViewModelEdgeCaseTests \
  vreaderTests/EPUBChapterNavigationRouterTests \
  vreaderTests/EPUBChapterWrapPendingTargetTests \
  vreaderTests/EPUBReaderHostLifecycleTests \
  vreaderTests/ReaderEngineTests \
  vreaderTests/ReaderContainerViewEngineDispatchTests \
  vreaderTests/EPUBBilingualOrchestratorTests \
  vreaderTests/EPUBSemanticResourceReaderTests \
  vreaderTests/EPUBSourceZIPValidationTests \
  vreaderTests/EPUBSourceBudgetTests \
  vreaderTests/SemanticXMLParserTests \
  vreaderTests/SemanticXMLSafetyTests \
  vreaderTests/SemanticXMLCancellationTests
run_lane package \
  vreaderTests/EPUBPackageReferenceTests \
  vreaderTests/EPUBPackageDecoderTests \
  vreaderTests/EPUBPackageLoaderTests
run_lane model \
  vreaderTests/SemanticIdentityTests \
  vreaderTests/SemanticSourceAnchorTests \
  vreaderTests/SemanticModelCodableTests
run_lane xhtml \
  vreaderTests/SemanticXHTMLStructureTests \
  vreaderTests/SemanticXHTMLSafetyTests \
  vreaderTests/SemanticXHTMLIntegrationTests
python3 - <<'PY'
from pathlib import Path
import json
paths = [Path(f'preparation/{lane}-test-result-path.txt').read_text() for lane in ['base', 'package', 'model', 'xhtml']]
if len(set(paths)) != 4:
    raise SystemExit('Lanes must have distinct completed result bundles')
summaries = [json.loads(Path(f'preparation/{lane}-test-summary.json').read_text()) for lane in ['base', 'package', 'model', 'xhtml']]
print('All fifteen semantic suites passed in four sequential disjoint lanes; distinct tests:', sum(s['totalTestCount'] for s in summaries))
PY
