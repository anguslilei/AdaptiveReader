import unittest
from fixtures import CHAPTER
from resource_reader import SourceError
from xml_source import parse_source, text_runs, resolve_run, node_path

class XMLTests(unittest.TestCase):
    def test_runs_unicode_comments_pi(self):
        root,encoding=parse_source(CHAPTER)
        self.assertEqual(encoding,'UTF-8')
        runs=text_runs(root)
        for run in runs: self.assertEqual(resolve_run(root,run['selector']),run['text'])
        text=''.join(x['text'] for x in runs)
        self.assertIn('A中😀尾后终',text); self.assertNotIn('hidden',text)
        emoji=next(x for x in runs if x['text']=='中😀'); self.assertEqual(emoji['end_utf16'],3)
        self.assertEqual(node_path(root),[])
    def test_consecutive_comment_tails(self):
        root,_=parse_source('<p xmlns="http://www.w3.org/1999/xhtml">甲<!--a-->乙<!--b-->丙<?p x?>丁<em>é👩‍💻&amp;&#x4e2d;</em>尾</p>'.encode())
        runs=text_runs(root)
        self.assertEqual(''.join(x['text'] for x in runs),'甲乙丙丁é👩‍💻&中尾')
        for run in runs: self.assertEqual(resolve_run(root,run['selector']),run['text'])
    def test_encoding(self):
        for data,enc in [(b'\xef\xbb\xbf<p>ok</p>','UTF-8'),('<?xml version="1.0" encoding="UTF-16"?><p>中😀</p>'.encode('utf-16'),'UTF-16')]:
            self.assertEqual(parse_source(data)[1],enc)
        for data in [b'<?xml version="1.0" encoding="ISO-8859-1"?><p>x</p>',b'\xef\xbb\xbf<?xml version="1.0" encoding="UTF-16"?><p>x</p>',b'<?xml version="1.0" encoding="UTF-16"?><p>x</p>',b'<p>\xff</p>']:
            with self.subTest(data=data), self.assertRaises(SourceError): parse_source(data)
    def test_unsafe_malformed_limits(self):
        for data in [b'<!DOCTYPE p [<!ENTITY x SYSTEM "file:///etc/passwd">]><p>&x;</p>',b'<!DOCTYPE p><p/>',b'<p>',b'']:
            with self.subTest(data=data), self.assertRaises(SourceError): parse_source(data)
        with self.assertRaises(SourceError): parse_source(b'<p><a/><b/></p>',max_nodes=2)
        with self.assertRaises(SourceError): parse_source(b'<p><a><b/></a></p>',max_depth=2)
        with self.assertRaises(SourceError): parse_source(b'<p/>',cancelled=lambda:True)
    def test_bad_selectors(self):
        root,_=parse_source(b'<p><!--x--><em>a</em></p>')
        for selector in [{'path':[9],'slot':'text'},{'path':[0],'slot':'text'},{'path':[],'slot':'bad'},{'path':[-1],'slot':'tail'}]:
            with self.assertRaises(SourceError): resolve_run(root,selector)
    def test_bomless_utf16_utf32_rejected(self):
        for encoding in ['utf-16-le','utf-16-be','utf-32-le','utf-32-be']:
            for xml in ['<p>ascii</p>','<?xml version="1.0" encoding="UTF-16"?><p/>','<!DOCTYPE p [<!ENTITY x "hidden">]><p>&x;</p>']:
                with self.subTest(encoding=encoding,xml=xml), self.assertRaises(SourceError): parse_source(xml.encode(encoding))
    def test_rtl_and_late_cancel(self):
        root,_=parse_source('<p>עברית العربية &amp; 😀</p>'.encode());runs=text_runs(root)
        self.assertEqual(runs[0]['text'],'עברית العربية & 😀')
        self.assertEqual(resolve_run(root,runs[0]['selector']),runs[0]['text'])
        calls=0
        def cancel():
            nonlocal calls
            calls+=1;return calls>=4
        with self.assertRaises(SourceError): parse_source(b'<p><em>a</em></p>',cancelled=cancel)
        self.assertGreaterEqual(calls,4)
    def test_cached_paths_match_original(self):
        from xml_source import source_paths
        root,_=parse_source(CHAPTER);paths=source_paths(root)
        for node in root.iter(): self.assertEqual(node_path(node,paths),node_path(node))
        self.assertEqual(text_runs(root,paths=paths),text_runs(root))
    def test_cancel_text_traversal_after_start(self):
        root,_=parse_source(CHAPTER);calls=0
        def cancel():
            nonlocal calls
            calls+=1;return calls>=4
        with self.assertRaises(SourceError): text_runs(root,cancelled=cancel)
        self.assertEqual(calls,4)
