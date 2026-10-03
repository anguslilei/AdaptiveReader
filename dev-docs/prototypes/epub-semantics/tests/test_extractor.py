import dataclasses
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from fixtures import CHAPTER, book
from resource_reader import SourceResource, SourceError
from extractor import extract_section
from xml_source import parse_source, resolve_run

class ExtractionTests(unittest.TestCase):
    def resource(self,data=CHAPTER):
        return SourceResource('OPS/chapter.xhtml',data,hashlib.sha256(data).hexdigest(),'a'*64)
    def blocks(self,roots):
        for b in roots:
            yield b
            yield from self.blocks(b.get('children',[]))
    def test_structure_and_roundtrip(self):
        src=self.resource(); a=extract_section(src,0); self.assertEqual(a,extract_section(src,0))
        root,_=parse_source(CHAPTER); blocks=list(self.blocks(a['blocks'])); kinds=[b['kind'] for b in blocks]
        for kind in ['heading','paragraph','list','listItem','quote','figure','caption','opaque']: self.assertIn(kind,kinds)
        self.assertEqual(len({b['id'] for b in blocks}),len(blocks))
        for b in blocks:
            for run in b.get('runs',[]): self.assertEqual(resolve_run(root,run['selector']),run['text'])
        self.assertNotIn('secret',json.dumps(a))
        para=next(b for b in blocks if b.get('text')=='A中😀尾后终')
        self.assertTrue(any(x['kind']=='em' for x in para['inline']))
        figure=next(b for b in blocks if b['kind']=='figure');self.assertEqual(figure['assets'][0]['src'],'a.png')
    def test_distinct_identity(self):
        src=self.resource(b'<html xmlns="http://www.w3.org/1999/xhtml"><body><p>x</p><p>x</p></body></html>');a=extract_section(src,0)
        self.assertNotEqual(a['blocks'][0]['id'],a['blocks'][1]['id'])
        for changed in [dataclasses.replace(src,archive_sha256='b'*64),dataclasses.replace(src,path='other.xhtml'),self.resource(src.data.replace(b'>x<',b'>y<'))]:
            self.assertNotEqual(a['blocks'][0]['id'],extract_section(changed,0)['blocks'][0]['id'])
        self.assertNotEqual(a['blocks'][0]['id'],extract_section(src,1)['blocks'][0]['id'])
        self.assertNotEqual(a['blocks'][0]['id'],extract_section(src,0,version='next')['blocks'][0]['id'])
    def test_wrappers_opaque_and_no_duplicate(self):
        src=self.resource(b'<html xmlns="http://www.w3.org/1999/xhtml"><body><div><p>x</p><blockquote>before<p>q</p>after</blockquote></div><svg xmlns="http://www.w3.org/2000/svg"><text>graphic</text></svg></body></html>')
        a=extract_section(src,0);blocks=list(self.blocks(a['blocks']))
        self.assertEqual(sum(b.get('text')=='x' for b in blocks),1)
        self.assertEqual(sum(b.get('text')=='q' for b in blocks),1)
        self.assertTrue(any(b['kind']=='opaque' for b in blocks))
        self.assertIn('before',''.join(b.get('text','') for b in blocks)); self.assertIn('after',''.join(b.get('text','') for b in blocks))
        self.assertEqual(src.data,self.resource(src.data).data)
    def test_empty_cancel_and_invalid_root(self):
        self.assertEqual(extract_section(self.resource(b'<html xmlns="http://www.w3.org/1999/xhtml"><body/></html>'),0)['blocks'],[])
        for data in [b'<p/>',b'<html xmlns="http://www.w3.org/1999/xhtml"/>']:
            with self.assertRaises(SourceError): extract_section(self.resource(data),0)
        with self.assertRaises(SourceError): extract_section(self.resource(),0,cancelled=lambda:True)
    def test_cli_success_failures(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=book(Path(tmp)/'a.epub');cli=Path(__file__).resolve().parents[1]/'__main__.py'
            def run(*args): return subprocess.run([sys.executable,str(cli),str(path),*args],capture_output=True,text=True)
            p=run(); self.assertEqual(p.returncode,0,p.stderr); json.loads(p.stdout)
            for args in [('--spine','-1'),('--spine','99'),('--resource-limit','2')]:
                p=run(*args);self.assertEqual(p.returncode,2);self.assertEqual(p.stdout,'');self.assertTrue(p.stderr)
            for bad in [b'<p>',b'<p/>']:
                book(path,chapter=bad);p=run();self.assertEqual(p.returncode,2);self.assertEqual(p.stdout,'')
            path.write_bytes(b'bad');p=run();self.assertEqual(p.returncode,2);self.assertEqual(p.stdout,'')
