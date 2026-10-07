# Purpose: Version allocation regression: hidden duplicates, bounds, idempotency and actual CLI evidence.
from pathlib import Path
import json
import runpy
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / 'scripts/prepare-semantic-version.py'
API = runpy.run_path(str(TOOL))
SHA = '54930d465d57cdce5699f36cf9edd14b222e3655'
BASELINE = ('targets:\n  vreader:\n    settings:\n      base:\n'
            '        CURRENT_PROJECT_VERSION: 1054\n        MARKETING_VERSION: 3.67.12\n'
            '    info:\n      CFBundleVersion: $(CURRENT_PROJECT_VERSION)\n'
            '      CFBundleShortVersionString: $(MARKETING_VERSION)\n'
            '      "UISupportedInterfaceOrientations~ipad": []\n')

class VersionAllocationTests(unittest.TestCase):
    def test_positive_and_candidate_rerun(self):
        candidate, allocation = API['prepare'](BASELINE, BASELINE, SHA)
        self.assertEqual(candidate, BASELINE.replace('1054', '1055').replace('3.67.12', '3.67.13'))
        self.assertEqual(allocation['candidate'], dict(marketing='3.67.13', build=1055))
        self.assertEqual(API['prepare'](BASELINE, candidate, SHA)[0], candidate)

    def test_hidden_duplicate_values_and_keys(self):
        for key, value in [('MARKETING_VERSION', '9.0.0'), ('CURRENT_PROJECT_VERSION', '9999')]:
            lines = [f'{key}: "{value}"', f"{key}: '{value}'", f'{key}: {value} # comment',
                     f'"{key}": {value}', f"'{key}': {value}", f'{key} : {value}',
                     f'flow: {{{key}: "{value}"}}', f'flow: {{"{key}": "{value}"}}']
            escaped = key.replace('_', r'\u005f', 1)
            lines.append(f'"{escaped}": {value}')
            for line in lines:
                with self.subTest(line=line):
                    with self.assertRaises(ValueError):
                        API['prepare'](BASELINE, BASELINE + '\nextra:\n  ' + line + '\n', SHA)

    def test_single_noncanonical_field_rejected(self):
        for source in [BASELINE.replace('MARKETING_VERSION: 3.67.12', 'MARKETING_VERSION: "3.67.12"'),
                       BASELINE.replace('CURRENT_PROJECT_VERSION: 1054', 'CURRENT_PROJECT_VERSION: 1054 # build'),
                       BASELINE.replace('MARKETING_VERSION:', '"MARKETING_VERSION":'),
                       BASELINE.replace('CURRENT_PROJECT_VERSION: 1054', 'CURRENT_PROJECT_VERSION: 01054')]:
            with self.subTest(source=source):
                with self.assertRaises(ValueError):
                    API['prepare'](source, source, SHA)

    def test_explicit_anchored_aliased_and_complex_yaml_keys(self):
        for key, value in [('MARKETING_VERSION', '9.0.0'), ('CURRENT_PROJECT_VERSION', '9999')]:
            for addition in [f'  ? {key}\n  : "{value}"\n',
                             f'  &version {key}: "{value}"\n',
                             f'  !!str {key}: "{value}"\n',
                             f'  ? &version {key}\n  : "{value}"\n',
                             f'  first: &version {key}\n  *version: "{value}"\n',
                             f'  <<: {{{key}: "{value}"}}\n',
                             f'  ? [{key}]\n  : "{value}"\n']:
                with self.subTest(addition=addition):
                    with self.assertRaises(ValueError):
                        API['prepare'](BASELINE, BASELINE + '\nextra:\n' + addition, SHA)

    def test_yaml_strings_are_not_mapping_keys(self):
        source = BASELINE + 'script: |\n  print("{MARKETING_VERSION: 9.0.0}")\n'
        self.assertEqual(API['pair'](source), ((3, 67, 12), 1054))

    def test_multiple_documents_and_invalid_yaml_rejected(self):
        for source in [BASELINE + '---\nMARKETING_VERSION: 9.0.0\n', BASELINE + 'bad: [\n']:
            with self.assertRaises(ValueError):
                API['prepare'](BASELINE, source, SHA)

    def test_multiline_plain_version_cannot_hide_a_continuation(self):
        for source in [BASELINE.replace('MARKETING_VERSION: 3.67.12\n', 'MARKETING_VERSION: 3.67.12\n          9.0.0\n'),
                       BASELINE.replace('CURRENT_PROJECT_VERSION: 1054\n', 'CURRENT_PROJECT_VERSION: 1054\n          9999\n')]:
            with self.assertRaises(ValueError):
                API['prepare'](BASELINE, source, SHA)

    def test_missing_fields_and_mixed_pairs(self):
        for source in [BASELINE.replace('        MARKETING_VERSION: 3.67.12\n', ''),
                       BASELINE.replace('1054', '1055'), BASELINE.replace('3.67.12', '3.67.13'),
                       BASELINE.replace('1054', '1056'), BASELINE.replace('1054', '0')]:
            with self.subTest(source=source):
                with self.assertRaises(ValueError):
                    API['prepare'](BASELINE, source, SHA)

    def test_allocation_overflow(self):
        for source in [BASELINE.replace('3.67.12', '3.67.2147483647'),
                       BASELINE.replace('1054', '2147483647')]:
            with self.assertRaises(ValueError):
                API['prepare'](source, source, SHA)

    def test_sha_must_be_exact_lowercase_hex(self):
        for sha in ['', SHA[:-1], 'F' * 40, 'z' * 40]:
            with self.assertRaises(ValueError):
                API['prepare'](BASELINE, BASELINE, sha)

    def test_comment_only_mentions_do_not_add_fields(self):
        source = BASELINE + '# MARKETING_VERSION: "9.0.0"\n# {CURRENT_PROJECT_VERSION: 9999}\n'
        self.assertEqual(API['pair'](source), ((3, 67, 12), 1054))

    def test_cli_writes_exact_allocation_and_preserves_baseline(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            baseline = root / 'baseline.yml'
            source = root / 'input.yml'
            output = root / 'evidence'
            baseline.write_text(BASELINE)
            source.write_text(BASELINE)
            command = [sys.executable, str(TOOL), '--baseline-yml', str(baseline),
                       '--baseline-sha', SHA, '--input-yml', str(source), '--output-dir', str(output)]
            subprocess.run(command, check=True, capture_output=True)
            candidate = source.read_bytes()
            subprocess.run(command, check=True, capture_output=True)
            self.assertEqual(source.read_bytes(), candidate)
            self.assertEqual((output / 'project.yml').read_bytes(), candidate)
            self.assertEqual((output / 'version-baseline.yml').read_text(), BASELINE)
            self.assertEqual(baseline.read_text(), BASELINE)
            self.assertEqual((output / 'version-baseline-sha.txt').read_text(), SHA + '\n')
            self.assertEqual(json.loads((output / 'version-allocation.json').read_text())['candidate'],
                             dict(marketing='3.67.13', build=1055))

if __name__ == '__main__':
    unittest.main()
