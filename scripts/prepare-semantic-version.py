# Purpose: Allocate one patch/build from a pinned merged-main source; reruns are idempotent.
from pathlib import Path
import argparse
import json
import re
import yaml

LIMIT = 2147483647

def version_fields(text):
    # Inspect YAML nodes, not a dict: composing retains duplicate mapping entries.
    # BaseLoader composes scalar/mapping/sequence nodes without object construction.
    if len(text.encode('utf-8')) > 2 * 1024 * 1024:
        raise ValueError('Version input exceeds the bounded YAML ceiling')
    try:
        if any(isinstance(event, yaml.events.AliasEvent) for event in yaml.parse(text, Loader=yaml.BaseLoader)):
            raise ValueError('YAML aliases are unsupported for exact version allocation')
        document = yaml.compose(text, Loader=yaml.BaseLoader)
    except (yaml.YAMLError, RecursionError) as error:
        raise ValueError('Expected one valid YAML document') from error
    if not isinstance(document, yaml.nodes.MappingNode):
        raise ValueError('Expected a YAML project mapping')
    lines = text.splitlines()
    fields = {'MARKETING_VERSION': [], 'CURRENT_PROJECT_VERSION': []}
    pending = [document]
    while pending:
        node = pending.pop()
        if isinstance(node, yaml.nodes.MappingNode):
            for key, value in node.value:
                if not isinstance(key, yaml.nodes.ScalarNode) or key.value == '<<':
                    raise ValueError('Complex/merged YAML keys are unsupported')
                if key.value in fields:
                    if (not isinstance(value, yaml.nodes.ScalarNode) or value.style is not None or
                            value.start_mark.line != key.start_mark.line or
                            value.end_mark.line != key.start_mark.line):
                        raise ValueError('Version value must occupy one canonical scalar line')
                    fields[key.value].append(lines[key.start_mark.line])
                pending.append(value)
        elif isinstance(node, yaml.nodes.SequenceNode):
            pending.extend(node.value)
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
