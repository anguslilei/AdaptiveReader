"""Experimental source-preserving semantic block extraction; no CFI claim."""
import hashlib
import json
from lxml import etree
from errors import SourceError, check_cancelled
from xml_source import parse_source, node_path, text_runs, run_for, visible_descendants, excluded, source_paths

XHTML = 'http://www.w3.org/1999/xhtml'
VERSION = 'adaptive-epub-reference/1'
INLINE = {'a', 'em', 'strong', 'b', 'i', 'span', 'code', 'br', 'sup', 'sub',
          'small', 's', 'u', 'mark', 'abbr', 'q', 'cite', 'img', 'ruby', 'rt', 'rp'}
CONTAINERS = {'div', 'section', 'article', 'main', 'header', 'footer', 'nav', 'aside'}


def extract_section(resource, spine_occurrence, cancelled=lambda: False, version=VERSION,
                    max_nodes=50000, max_depth=96):
    if type(spine_occurrence) is not int or spine_occurrence < 0:
        raise SourceError('invalid spine occurrence')
    if hashlib.sha256(resource.data).hexdigest() != resource.sha256:
        raise SourceError('resource digest mismatch')
    root, encoding = parse_source(resource.data, max_nodes, max_depth, cancelled)
    paths = source_paths(root, cancelled)
    ns = '{' + XHTML + '}'
    bodies = root.findall(ns + 'body')
    if root.tag != ns + 'html' or len(bodies) != 1:
        raise SourceError('expected XHTML html with exactly one body')

    def name(node):
        return etree.QName(node).localname if isinstance(node.tag, str) else None

    def identity(kind, selector):
        # JSON array encodes each tuple component without concatenation ambiguity.
        fields = [resource.archive_sha256, resource.path, resource.sha256,
                  spine_occurrence, selector, kind, version]
        return hashlib.sha256(json.dumps(fields, ensure_ascii=False,
                              separators=(',', ':')).encode()).hexdigest()

    def base(node, kind, selector=None):
        check_cancelled(cancelled)
        source = selector or {'path': node_path(node, paths)}
        return {'id': identity(kind, source), 'kind': kind, 'source': source}

    def prose(node, kind):
        b = base(node, kind)
        runs = text_runs(node, cancelled, paths)
        b.update(runs=runs, text=''.join(r['text'] for r in runs))
        b['inline'] = [{'kind': name(child), 'source': {'path': node_path(child, paths)},
                        'attributes': dict(child.attrib)}
                       for child in visible_descendants(node)
                       if isinstance(child.tag, str) and etree.QName(child).namespace == XHTML
                       and name(child) in INLINE]
        return b

    def segment(node, slot):
        run = run_for(node, slot, paths)
        if run is None:
            return []
        b = base(node, 'paragraph', run['selector'])
        b.update(runs=[run], text=run['text'], inline=[])
        return [b]

    def children(node):
        result = segment(node, 'text')
        for child in node:
            result.extend(visit(child))
            result.extend(segment(child, 'tail'))
        return result

    def visit(node):
        check_cancelled(cancelled)
        if not isinstance(node.tag, str):
            return []
        tag = name(node)
        namespace = etree.QName(node).namespace
        if excluded(node):
            return []
        if namespace != XHTML:
            return [opaque(node)]
        if tag in CONTAINERS:
            b = base(node, 'container'); b['children'] = children(node)
            return [b]
        if tag in ('ul', 'ol', 'li', 'blockquote', 'figure'):
            kind = {'ul': 'list', 'ol': 'list', 'li': 'listItem',
                    'blockquote': 'quote', 'figure': 'figure'}[tag]
            b = base(node, kind); b['children'] = children(node)
            if tag in ('ul', 'ol'):
                b['ordered'] = tag == 'ol'
            if tag == 'figure':
                b['assets'] = [dict(n.attrib) for n in visible_descendants(node) if n.tag == ns + 'img']
                b['caption_ids'] = [c['id'] for c in b['children'] if c['kind'] == 'caption']
            return [b]
        if tag == 'img':
            b = base(node, 'image'); b['asset'] = dict(node.attrib)
            return [b]
        if tag in {'p', 'figcaption', *('h' + str(i) for i in range(1, 7))}:
            # Unsupported/nested structural descendants retain opaque source identity.
            if any(isinstance(n.tag, str) and (
                    etree.QName(n).namespace != XHTML or name(n) not in INLINE | {'script', 'style'})
                    for n in visible_descendants(node)):
                return [opaque(node)]
            kind = 'caption' if tag == 'figcaption' else 'heading' if tag.startswith('h') else 'paragraph'
            b = prose(node, kind)
            if kind == 'heading':
                b['level'] = int(tag[1])
            return [b]
        if tag in INLINE:
            return [prose(node, 'paragraph')]
        return [opaque(node)]

    def opaque(node):
        b = prose(node, 'opaque')
        b.update(tag=node.tag, attributes=dict(node.attrib), precision='original-subtree-selector')
        # The source subtree is retained through its byte identity and selector,
        # rather than serializing active markup into a prospective renderer.
        return b

    blocks = children(bodies[0])
    return {'schema': version, 'precision': 'original-DOM-text-node-UTF16; not-CFI',
            'source': {'archive_sha256': resource.archive_sha256, 'path': resource.path,
                       'sha256': resource.sha256, 'encoding': encoding,
                       'spine_occurrence': spine_occurrence}, 'blocks': blocks}
