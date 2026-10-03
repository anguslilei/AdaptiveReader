import dataclasses
import hashlib
import os
from pathlib import Path
import tempfile
import threading
import unittest
import zipfile
from fixtures import book, OPF, CONTAINER, CHAPTER
from resource_reader import EpubSourceReader, Limits, SourceError
from package_manifest import resolve_href

class ResourceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.path = book(Path(self.tmp.name) / 'b.epub')
    def test_bytes_identity_and_spine(self):
        digest = hashlib.sha256(self.path.read_bytes()).hexdigest()
        with EpubSourceReader(self.path, digest) as r:
            self.assertEqual(r.manifest()['spine'][0]['path'], 'OPS/chapter.xhtml')
            src = r.read('OPS/chapter.xhtml')
            self.assertEqual(src.data, CHAPTER); self.assertEqual(src.archive_sha256, digest)
            self.assertEqual(src.sha256, hashlib.sha256(CHAPTER).hexdigest())
        with self.assertRaises(SourceError): r.read('OPS/chapter.xhtml')
        r.close()
    def test_expected_mismatch(self):
        with self.assertRaises(SourceError): EpubSourceReader(self.path, '0'*64)
    def test_unsafe_entries(self):
        for name in ['../x', '/x', 'a\\b', 'C:/x', 'a/../x', 'OPS/chapter.xhtml']:
            with self.subTest(name=name):
                book(self.path, extra=[(name,b'x')])
                with self.assertRaises(SourceError): EpubSourceReader(self.path)
    def test_bounds(self):
        for limits in [Limits(archive_bytes=2), Limits(entries=2), Limits(compressed_bytes=2), Limits(resource_bytes=2), Limits(total_bytes=2)]:
            with self.subTest(limits=limits), self.assertRaises(SourceError):
                with EpubSourceReader(self.path, limits=limits) as r: r.read('OPS/chapter.xhtml')
        book(self.path, chapter=b'A'*10000, compression=zipfile.ZIP_DEFLATED)
        with self.assertRaises(SourceError): EpubSourceReader(self.path, limits=Limits(ratio=2))
    def test_aggregate_and_failed_read_closes(self):
        with EpubSourceReader(self.path, limits=Limits(total_bytes=len(CHAPTER))) as r:
            r.read('OPS/chapter.xhtml')
            with self.assertRaises(SourceError): r.read('OPS/chapter.xhtml')
            self.assertTrue(r.closed); self.assertTrue(r._file.closed)
    def test_missing_read_closes(self):
        r=EpubSourceReader(self.path)
        with self.assertRaises(SourceError): r.read('absent')
        self.assertTrue(r.closed)
    def test_cancellation(self):
        with self.assertRaises(SourceError): EpubSourceReader(self.path, cancelled=lambda: True)
        r=EpubSourceReader(self.path); r.cancelled=lambda: True
        with self.assertRaises(SourceError): r.read('OPS/chapter.xhtml')
        self.assertTrue(r.closed)
    def test_thread_and_reentrancy(self):
        r=EpubSourceReader(self.path); self.addCleanup(r.close); errors=[]
        def cross():
            try: r.read('OPS/chapter.xhtml')
            except SourceError: errors.append(True)
        t=threading.Thread(target=cross); t.start(); t.join(); self.assertEqual(errors,[True])
        def callback(): r.read('OPS/chapter.xhtml'); return False
        r.cancelled=callback
        with self.assertRaises(SourceError): r.read('OPS/chapter.xhtml')
        self.assertTrue(r.closed)
    def test_changed_source(self):
        r=EpubSourceReader(self.path)
        with self.path.open('ab') as f: f.write(b'x')
        with self.assertRaises(SourceError): r.read('OPS/chapter.xhtml')
        self.assertTrue(r.closed)
    def test_replacement_and_same_name_digest(self):
        r=EpubSourceReader(self.path); old=r.archive_sha256; r.close()
        stat=self.path.stat(); content=self.path.read_bytes().replace(b'opaque', b'OPAQUE'); self.path.write_bytes(content)
        os.utime(self.path, ns=(stat.st_atime_ns,stat.st_mtime_ns))
        with self.assertRaises(SourceError): EpubSourceReader(self.path, old)
        r=EpubSourceReader(self.path); newer=self.path.with_suffix('.new'); book(newer); newer.replace(self.path)
        with self.assertRaises(SourceError): r.read('OPS/chapter.xhtml')
    def test_bad_zip_and_crc(self):
        self.path.write_bytes(b'bad')
        with self.assertRaises(SourceError): EpubSourceReader(self.path)
        book(self.path); data=self.path.read_bytes().replace(b'opaque', b'OPAQUE'); self.path.write_bytes(data)
        with EpubSourceReader(self.path) as r:
            with self.assertRaises(SourceError): r.read('OPS/chapter.xhtml')
    def test_manifest_rejections(self):
        variants=[OPF.replace(b'id="c"',b'id=""'),OPF.replace(b'idref="c"',b'idref="missing"'),OPF.replace(b'chapter.xhtml',b'absent.xhtml'),OPF.replace(b'application/xhtml+xml',b'text/html'),OPF.replace(b'<itemref idref="c"/>',b''),OPF.replace(b'http://www.idpf.org/2007/opf',b'wrong'),OPF.replace(b'<spine>',b'<spine xml:base="x">'),OPF.replace(b'</manifest>',b'<item id="c" href="x" media-type="x"/></manifest>')]
        for opf in variants:
            with self.subTest(opf=opf), self.assertRaises(SourceError):
                book(self.path,opf=opf)
                with EpubSourceReader(self.path) as r: r.manifest()
    def test_rootfile_ambiguity_and_namespace(self):
        for c in [CONTAINER.replace(b'</rootfiles>',b'<rootfile full-path="x" media-type="application/oebps-package+xml"/></rootfiles>'),CONTAINER.replace(b'urn:oasis:names:tc:opendocument:xmlns:container',b'wrong')]:
            book(self.path,container=c)
            with self.assertRaises(SourceError):
                with EpubSourceReader(self.path) as r: r.manifest()
    def test_repeated_spine(self):
        book(self.path,opf=OPF.replace(b'</spine>',b'<itemref idref="c"/></spine>'))
        with EpubSourceReader(self.path) as r:
            self.assertEqual([x['occurrence'] for x in r.manifest()['spine']], [0,1])
    def test_href_contract(self):
        self.assertEqual(resolve_href('OPS/book.opf','../章.xhtml'),'章.xhtml')
        self.assertEqual(resolve_href('OPS/book.opf','100%25.xhtml'),'OPS/100%.xhtml')
        for href in ['../../x','/x','//host/x','https://a/x','x?q','x#f','x%2Fz','x%3Fq','x%23f','x%00','x%GG','%252e%252e/x','x\\z','C:/x']:
            with self.subTest(href=href), self.assertRaises(SourceError): resolve_href('OPS/book.opf',href)
    def test_symlink_encryption_and_method(self):
        for kind in ['symlink','encrypt','method']:
            book(self.path)
            if kind=='symlink':
                with zipfile.ZipFile(self.path,'a') as z:
                    info=zipfile.ZipInfo('link');info.create_system=3;info.external_attr=0o120777 << 16;z.writestr(info,b'x')
            else:
                data=bytearray(self.path.read_bytes());central=data.index(b'PK\x01\x02')
                offset=central+(8 if kind=='encrypt' else 10)
                data[offset:offset+2]=(1 if kind=='encrypt' else 99).to_bytes(2,'little');self.path.write_bytes(data)
            with self.subTest(kind=kind), self.assertRaises(SourceError): EpubSourceReader(self.path)
    def test_declared_size_mismatch(self):
        book(self.path);data=bytearray(self.path.read_bytes());central=data.rindex(b'PK\x01\x02');offset=central+24
        data[offset:offset+4]=(len(CHAPTER)+1).to_bytes(4,'little');self.path.write_bytes(data)
        with self.assertRaises(SourceError):
            with EpubSourceReader(self.path) as r: r.read('OPS/chapter.xhtml')
    def test_nested_context(self):
        with EpubSourceReader(self.path) as r:
            with self.assertRaises(SourceError):
                with r: pass
    def test_forged_prefix_length_and_crc(self):
        import zlib
        for compression in [zipfile.ZIP_STORED,zipfile.ZIP_DEFLATED]:
            book(self.path,compression=compression)
            data=bytearray(self.path.read_bytes());central=data.rindex(b'PK\x01\x02')
            prefix=CHAPTER[:20]
            data[central+16:central+20]=zlib.crc32(prefix).to_bytes(4,'little')
            data[central+24:central+28]=len(prefix).to_bytes(4,'little')
            self.path.write_bytes(data)
            with self.subTest(compression=compression), self.assertRaises(SourceError):
                with EpubSourceReader(self.path) as r: r.read('OPS/chapter.xhtml')
    def test_interrupted_read_closes(self):
        r=EpubSourceReader(self.path)
        def interrupted(): raise KeyboardInterrupt()
        r.cancelled=interrupted
        with self.assertRaises(KeyboardInterrupt): r.read('OPS/chapter.xhtml')
        self.assertTrue(r.closed);self.assertTrue(r._file.closed)
    def test_normal_deflate_roundtrip(self):
        book(self.path,compression=zipfile.ZIP_DEFLATED)
        with EpubSourceReader(self.path) as r: self.assertEqual(r.read('OPS/chapter.xhtml').data,CHAPTER)
