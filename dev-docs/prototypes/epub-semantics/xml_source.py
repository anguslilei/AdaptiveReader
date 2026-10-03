"""Strict XML parsing and original logical text-node UTF-16 locations."""
import re
from lxml import etree
from errors import SourceError, check_cancelled


def parse_source(data, max_nodes=50000, max_depth=96, cancelled=lambda: False):
    check_cancelled(cancelled)
    try:
        if data.startswith((b'\xff\xfe', b'\xfe\xff')):
            decoded = data.decode('utf-16')
            encoding = 'UTF-16'
        else:
            decoded = data.decode('utf-8-sig')
            encoding = 'UTF-8'
        if '\x00' in decoded:
            raise SourceError('unsupported XML byte encoding/NUL')
        declaration = re.match(r'\s*<\?xml\s+[^?]*encoding\s*=\s*[\'"]([^\'"]+)', decoded)
        if declaration and declaration[1].upper() != encoding:
            raise SourceError('unsupported or inconsistent XML encoding')
        if '<!DOCTYPE' in decoded or '<!ENTITY' in decoded:
            raise SourceError('DOCTYPE/entities unsupported')
        parser = etree.XMLParser(encoding=encoding, resolve_entities=False, load_dtd=False, no_network=True,
                                 recover=False, huge_tree=False, remove_comments=False,
                                 remove_pis=False, remove_blank_text=False, strip_cdata=False)
        root = etree.fromstring(data, parser)
        if root.getroottree().docinfo.doctype:
            raise SourceError('DOCTYPE unsupported')
    except (UnicodeError, etree.XMLSyntaxError, ValueError) as exc:
        if isinstance(exc, SourceError):
            raise
        raise SourceError(f'invalid source XML: {exc}') from exc
    check_cancelled(cancelled)
    stack = [(root, 1)]
    count = 0
    while stack:
        check_cancelled(cancelled)
        node, depth = stack.pop()
        count += 1
        if count > max_nodes or depth > max_depth:
            raise SourceError('XML node/depth limit exceeded')
        stack.extend((child, depth + 1) for child in node)
    return root, encoding


def node_path(node, paths=None):
    if paths is not None:
        return paths[node]
    indices = []
    while node.getparent() is not None:
        parent = node.getparent()
        indices.append(parent.index(node))
        node = parent
    return list(reversed(indices))


def run_for(node, slot, paths=None):
    text = getattr(node, slot)
    if not text:
        return None
    return {'selector': {'path': node_path(node, paths), 'slot': slot}, 'text': text,
            'start_utf16': 0, 'end_utf16': len(text.encode('utf-16-le')) // 2}


def text_runs(element, cancelled=lambda: False, paths=None):
    """No root tail; descendants include comment/PI tails, excluding their content."""
    runs = []
    def visit(node):
        check_cancelled(cancelled)
        if not isinstance(node.tag, str):
            return
        # Content excluded by semantic policy; following tail belongs to parent prose.
        if excluded(node):
            return
        if run := run_for(node, 'text', paths):
            runs.append(run)
        for child in node:
            visit(child)
            if run := run_for(child, 'tail', paths):
                runs.append(run)
    visit(element)
    return runs


def resolve_run(root, selector):
    node = root
    path = selector.get('path')
    if not isinstance(path, list):
        raise SourceError('invalid source path')
    for index in path:
        if type(index) is not int or index < 0 or index >= len(node):
            raise SourceError('invalid source path index')
        node = node[index]
    slot = selector.get('slot')
    if slot not in ('text', 'tail') or (slot == 'text' and not isinstance(node.tag, str)):
        raise SourceError('invalid source text slot')
    text = getattr(node, slot)
    if text is None:
        raise SourceError('source text slot absent')
    return text


def excluded(node):
    return isinstance(node.tag, str) and etree.QName(node).localname in ('script', 'style')


def visible_descendants(node):
    """Shared exclusion policy for structural classification and metadata."""
    for child in node:
        if not isinstance(child.tag, str) or excluded(child):
            continue
        yield child
        yield from visible_descendants(child)


def source_paths(root, cancelled=lambda: False):
    """Compute all-child paths once, avoiding repeated wide-sibling searches."""
    paths = {root: []}
    stack = [root]
    while stack:
        check_cancelled(cancelled)
        node = stack.pop()
        for index, child in enumerate(node):
            paths[child] = paths[node] + [index]
            stack.append(child)
    return paths
