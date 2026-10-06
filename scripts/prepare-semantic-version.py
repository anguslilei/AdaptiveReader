# Purpose: Allocate one patch/build from a pinned merged-main source; reruns are idempotent.
from pathlib import Path
import argparse
import json
import re

LIMIT = 2147483647

def version_fields(text):
    # Count keys before validating values; quotes/comments cannot hide duplicates.
    # Support the block mappings used by project.yml and detect flow overrides too.
    keys = re.compile(r"""(?:^[ \t]*|[{,][ \t]*)([A-Za-z_][A-Za-z0-9_]*|"(?:[^"\\]|\\.)*"|'(?:[^']|'')*')[ \t]*:""")
    fields = {'MARKETING_VERSION': [], 'CURRENT_PROJECT_VERSION': []}
    for line in text.splitlines():
        if line.lstrip().startswith('#'):
            continue
        for match in keys.finditer(line):
            key = match[1]
            if key.startswith('"'):
                try:
                    key = json.loads(key)
                except ValueError as error:
                    raise ValueError('Unsupported quoted mapping key') from error
            elif key.startswith("'"):
                key = key[1:-1].replace("''", "'")
            if key in fields:
                fields[key].append(line)
    return fields

def pair(text):
    fields = version_fields(text)
    if any(len(lines) != 1 for lines in fields.values()):
        raise ValueError('Expected exactly one unquoted marketing/build field')
    marketing = re.fullmatch(r'[ \t]*MARKETING_VERSION: ([0-9]+\.[0-9]+\.[0-9]+)[ \t]*', fields['MARKETING_VERSION'][0])
    builds = re.fullmatch(r'[ \t]*CURRENT_PROJECT_VERSION: ([0-9]+)[ \t]*', fields['CURRENT_PROJECT_VERSION'][0])
    if not marketing or not builds:
        raise ValueError('Version fields must use canonical unquoted numeric block syntax')
    version = tuple(map(int, marketing[1].split('.')))
    build = int(builds[1])
    if any(n < 0 or n > LIMIT for n in version) or not 1 <= build <= LIMIT:
        raise ValueError('Invalid version number bounds')
    if '.'.join(map(str, version)) != marketing[1] or str(build) != builds[1]:
        raise ValueError('Noncanonical version fields')
    return version, build

def prepare(baseline_text, input_text, baseline_sha):
    if not re.fullmatch(r'[0-9a-f]{40}', baseline_sha):
        raise ValueError('Invalid pinned baseline SHA')
    version, build = pair(baseline_text)
    if version[2] == LIMIT or build == LIMIT:
        raise ValueError('Version allocation overflow')
    candidate = ((version[0], version[1], version[2] + 1), build + 1)
    input_pair = pair(input_text)
    if input_pair not in [(version, build), candidate]:
        raise ValueError('Input pair is neither the pinned baseline nor its allocated candidate')
    output = re.sub(r'(?m)^([ \t]*)CURRENT_PROJECT_VERSION: [0-9]+[ \t]*$',
                    lambda m: m[1] + 'CURRENT_PROJECT_VERSION: ' + str(candidate[1]), input_text)
    output = re.sub(r'(?m)^([ \t]*)MARKETING_VERSION: [0-9]+\.[0-9]+\.[0-9]+[ \t]*$',
                    lambda m: m[1] + 'MARKETING_VERSION: ' + '.'.join(map(str, candidate[0])), output)
    if pair(output) != candidate:
        raise ValueError('Candidate generation failed')
    def record(value):
        return dict(marketing='.'.join(map(str, value[0])), build=value[1])
    allocation = dict(baseline_commit=baseline_sha, baseline=record((version, build)),
                      candidate=record(candidate), input_pair=record(input_pair))
    return output, allocation

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--baseline-yml', type=Path, required=True)
    parser.add_argument('--baseline-sha', required=True)
    parser.add_argument('--input-yml', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    baseline = args.baseline_yml.read_text()
    candidate, allocation = prepare(baseline, args.input_yml.read_text(), args.baseline_sha)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / 'version-baseline.yml').write_text(baseline)
    (args.output_dir / 'version-baseline-sha.txt').write_text(args.baseline_sha + '\n')
    (args.output_dir / 'version-allocation.json').write_text(json.dumps(allocation, indent=2) + '\n')
    args.input_yml.write_text(candidate)
    (args.output_dir / 'project.yml').write_text(candidate)
    print('Pinned version candidate:', allocation['candidate'])

if __name__ == '__main__':
    main()
