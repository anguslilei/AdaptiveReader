"""Tiny synthetic exact-structure fixtures: CI/structure-test exception."""
import sys
from pathlib import Path
import zipfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

CONTAINER = b'''<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OPS/book.opf" media-type="application/oebps-package+xml"/></rootfiles></container>'''
OPF = b'''<package xmlns="http://www.idpf.org/2007/opf"><manifest><item id="c" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="c"/></spine></package>'''
CHAPTER = '<html xmlns="http://www.w3.org/1999/xhtml"><body><h1>标题</h1><p>A<em>中😀</em><!--hidden-->尾<?pi secret?>后<br/>终</p><ul><li><p>one</p><ul><li>two</li></ul></li></ul><blockquote><p>quote</p></blockquote><figure><img src="a.png" alt="图"/><figcaption>caption</figcaption></figure><table><tr><td>opaque</td></tr></table><script>secret</script></body></html>'.encode()

def book(path, chapter=CHAPTER, opf=OPF, container=CONTAINER, extra=(), compression=zipfile.ZIP_STORED):
    with zipfile.ZipFile(path, 'w', compression=compression) as z:
        for name, data in [('META-INF/container.xml', container), ('OPS/book.opf', opf), ('OPS/chapter.xhtml', chapter), *extra]:
            z.writestr(name, data)
    return path
