"""Developer-only CLI. Commit complete JSON only after validation succeeds."""
import argparse
import dataclasses
import json
import sys
from resource_reader import EpubSourceReader, Limits, SourceError
from extractor import extract_section


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('epub')
    parser.add_argument('--spine', type=int, default=0)
    parser.add_argument('--expected-sha256')
    parser.add_argument('--resource-limit', type=int, default=Limits().resource_bytes)
    args = parser.parse_args(argv)
    try:
        limits = dataclasses.replace(Limits(), resource_bytes=args.resource_limit)
        with EpubSourceReader(args.epub, args.expected_sha256, limits) as reader:
            manifest = reader.manifest()
            if args.spine < 0 or args.spine >= len(manifest['spine']):
                raise SourceError('selected spine index out of range')
            item = manifest['spine'][args.spine]
            section = extract_section(reader.read(item['path']), item['occurrence'],
                                      max_nodes=limits.xml_nodes, max_depth=limits.xml_depth)
            output = json.dumps({'manifest': manifest, 'section': section}, ensure_ascii=False)
        sys.stdout.write(output + '\n')
        return 0
    except SourceError as exc:
        print(f'EPUB source error: {exc}', file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print('EPUB extraction interrupted', file=sys.stderr)
        return 130


if __name__ == '__main__':
    sys.exit(main())
