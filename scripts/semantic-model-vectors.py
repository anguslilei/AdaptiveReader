# Purpose: Independent standard-library canonical identity bytes/hash golden vectors.
from pathlib import Path
import argparse
import hashlib
import json
import struct

def vector(name, kind, path='OPS/a.xhtml', occurrence=0, node=(1, 2),
           text_range=(0, 2), role=2, ordinal=0, extractor=1):
    u32 = lambda n: struct.pack('>I', n)
    fields = dict(name=name, kind=kind, archive='00' * 32, schema=1, extractor=extractor)
    payload = (b'vreader.semantic-id.v1\0' + bytes([{'revision': 1, 'section': 2, 'block': 3}[kind]]) +
               bytes(32) + u32(1) + u32(extractor))
    if kind != 'revision':
        fields.update(path=path, resource='11' * 32, occurrence=occurrence)
        encoded = path.encode('utf-8')
        payload += u32(len(encoded)) + encoded + bytes.fromhex(fields['resource']) + u32(occurrence)
    if kind == 'block':
        fields.update(node=list(node), range=None if text_range is None else list(text_range),
                      role=role, ordinal=ordinal)
        payload += u32(len(node)) + b''.join(u32(n) for n in node) + bytes([text_range is not None])
        if text_range is not None:
            payload += u32(text_range[0]) + u32(text_range[1])
        payload += bytes([role]) + u32(ordinal)
    return dict(input=fields, preimage_hex=payload.hex(),
                sha256=hashlib.sha256(payload).hexdigest(), bytes=len(payload))

def vectors():
    return [
        vector('revision-v1', 'revision'), vector('section-v1', 'section'), vector('block-v1', 'block'),
        vector('nil-range', 'block', text_range=None), vector('zero-range', 'block', text_range=(0, 0)),
        vector('unicode-literal', 'block', path='OPS/章节😀/שלום%2F?#.xhtml',
               occurrence=4095, node=(), text_range=None, role=8, ordinal=4294967295),
        vector('nfc', 'section', path='OPS/é.xhtml'), vector('nfd', 'section', path='OPS/e\u0301.xhtml'),
        vector('max-version', 'revision', extractor=4294967295),
        vector('max-node', 'block', node=(4294967295,) * 96, text_range=(2097152, 2097152)),
    ]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    target = Path(__file__).resolve().parents[1] / 'dev-docs/verification/artifacts/feature-181/identity-vectors.json'
    expected = json.dumps(vectors(), ensure_ascii=False, indent=2) + '\n'
    if args.check:
        if target.read_text() != expected:
            raise SystemExit('Independent semantic identity vectors differ')
        print('Ten independent byte/hash vectors verified')
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(expected)

if __name__ == '__main__':
    main()
