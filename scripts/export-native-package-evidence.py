# Purpose: Source-pinned, bounded, reviewable evidence export without write credentials.
from pathlib import Path
import base64, hashlib, json, subprocess

root = Path('preparation')
common = ['debug-build.log', 'release-build.log', 'devices.json', 'generator-version.txt',
          'input-commit.txt', 'project.pbxproj', 'project.yml', 'test-udid.txt',
          'xcode-version.txt', 'test-xcode-version.txt', 'version-baseline-sha.txt',
          'version-baseline.yml', 'version-allocation.json']
lane_files = [f'{lane}-test-{suffix}' for lane in ['base', 'package', 'model']
              for suffix in ['command-status.txt', 'full.log', 'result-path.txt',
                             'start.txt', 'summary.json', 'tree.json', 'wrapper.log']]
members, missing = {}, []
def facts(path):
    data = path.read_bytes()
    return dict(bytes=len(data), sha256=hashlib.sha256(data).hexdigest(),
                git_blob_sha=subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip())
for name in common + lane_files:
    path = root / name
    if path.is_file(): members[name] = facts(path)
    else: missing.append(name)
source_paths = sorted(set(
    list(Path('vreader/Services/Semantic').rglob('*.swift')) +
    list(Path('vreaderTests/Services/Semantic').rglob('*.swift')) +
    list(Path('vreader/Models/Semantic').glob('*.swift')) +
    list(Path('vreaderTests/Models/Semantic').glob('*.swift')) +
    [Path('vreaderTests/Helpers') / n for n in ['EPUBPackageFixture.swift', 'EPUBSemanticZIPFixture.swift', 'SemanticXMLProbe.swift']] +
    [Path(n) for n in ['scripts/test-epub-package-contract.sh', 'scripts/test-native-semantic-foundations.sh',
                      'scripts/export-native-package-evidence.py', '.github/workflows/epub-package-contract.yml',
                      '.github/workflows/native-reader-check.yml', 'scripts/test-semantic-model-contract.sh',
                      '.github/workflows/semantic-model-contract.yml', 'scripts/semantic-model-vectors.py',
                      'scripts/prepare-semantic-version.py', 'scripts/__tests__/prepare-semantic-version.test.py',
                      'dev-docs/verification/artifacts/feature-181/identity-vectors.json']]))
expected_models = ['SemanticModelError', 'SemanticSHA256', 'SemanticArchivePath',
                   'SemanticRevision', 'SemanticResourceIdentity', 'SemanticUTF16Range',
                   'SemanticNodePath', 'SemanticLogicalAnchor', 'SemanticID']
expected_tests = ['SemanticIdentityTests', 'SemanticSourceAnchorTests', 'SemanticModelCodableTests']
required = ([Path('vreader/Models/Semantic') / (n + '.swift') for n in expected_models] +
            [Path('vreaderTests/Models/Semantic') / (n + '.swift') for n in expected_tests])
if any(not p.is_file() for p in source_paths + required):
    raise SystemExit('Missing named source/tool/vector evidence path')
source = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
manifest = dict(source_commit=source, members=members, missing_members=missing,
                source_files={str(p): facts(p) for p in source_paths})
(root / 'evidence-export.json').write_text(json.dumps(manifest, indent=2) + '\n')
# Full compiler/test logs stay in the artifact, with byte counts/digests above.
# Export only this explicit non-secret allowlist; never arbitrary workspace files.
export_names = [n for n in common + lane_files if not n.endswith('-build.log') and not n.endswith('-full.log')]
export_names += ['evidence-export.json']
total = sum((root / n).stat().st_size for n in export_names if (root / n).is_file())
if total > 8 * 1024 * 1024:
    raise SystemExit('Evidence console payload exceeds bounded ceiling')
for name in export_names:
    path = root / name
    if not path.is_file(): continue
    packed = base64.b64encode(path.read_bytes()).decode('ascii')
    for index, offset in enumerate(range(0, len(packed), 16000)):
        print(f'EPUB_PACKAGE_EXPORT {name} {index} {packed[offset:offset+16000]}')
print('EPUB_PACKAGE_EXPORT_COMPLETE ' + source)
