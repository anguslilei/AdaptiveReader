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
