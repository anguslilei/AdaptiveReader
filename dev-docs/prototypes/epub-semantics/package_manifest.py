"""Strict supported subset of EPUB container, OPF and local URI resolution."""
import posixpath
import re
from urllib.parse import unquote, urlsplit
from errors import SourceError, check_cancelled
from xml_source import parse_source

CONTAINER = 'urn:oasis:names:tc:opendocument:xmlns:container'
OPF = 'http://www.idpf.org/2007/opf'
XML_BASE = '{http://www.w3.org/XML/1998/namespace}base'


def resolve_href(package_path, href):
    if not href or '\\' in href or '\x00' in href or '?' in href or '#' in href:
        raise SourceError('unsupported resource URI')
    if re.search(r'%(?![0-9a-fA-F]{2})', href):
        raise SourceError('malformed percent escape')
    if re.search(r'%(?:2f|5c|3f|23|00)', href, re.I):
        raise SourceError('encoded URI separator/delimiter')
    try:
        parts = urlsplit(href)
        decoded = unquote(href, encoding='utf-8', errors='strict')
    except (ValueError, UnicodeError) as exc:
        raise SourceError('invalid URI encoding') from exc
    if (parts.scheme or parts.netloc or decoded.startswith('/')
            or re.match(r'^[A-Za-z]:', decoded) or re.search(r'%[0-9a-fA-F]{2}', decoded)):
        raise SourceError('external/absolute/double-encoded URI')
    path = posixpath.normpath(posixpath.join(posixpath.dirname(package_path), decoded))
    if path in ('.', '..') or path.startswith('../'):
        raise SourceError('resource URI escapes archive')
    return path


def read_manifest(read, entries, limits, cancelled):
    def xml(path):
        root, _ = parse_source(read(path).data, limits.xml_nodes, limits.xml_depth, cancelled)
        if any(XML_BASE in node.attrib for node in root.iter() if isinstance(node.tag, str)):
            raise SourceError('xml:base unsupported')
        return root
    container = xml('META-INF/container.xml')
    if container.tag != '{' + CONTAINER + '}container':
        raise SourceError('unsupported container namespace/root')
    roots = container.findall('./{' + CONTAINER + '}rootfiles/{' + CONTAINER + '}rootfile')
    roots = [r for r in roots if r.get('media-type') == 'application/oebps-package+xml']
    if len(roots) != 1:
        raise SourceError('missing/ambiguous supported rootfile')
    package_path = resolve_href('', roots[0].get('full-path', ''))
    package = xml(package_path)
    ns = '{' + OPF + '}'
    if package.tag != ns + 'package':
        raise SourceError('unsupported OPF namespace/root')
    manifests, spines = package.findall(ns + 'manifest'), package.findall(ns + 'spine')
    if len(manifests) != 1 or len(spines) != 1:
        raise SourceError('missing/ambiguous manifest or spine')
    items = {}
    for item in manifests[0].findall(ns + 'item'):
        check_cancelled(cancelled)
        identifier = item.get('id')
        if not identifier or identifier in items:
            raise SourceError('missing/duplicate manifest ID')
        path = resolve_href(package_path, item.get('href', ''))
        if path not in entries or entries[path].is_dir():
            raise SourceError('manifest resource missing')
        items[identifier] = {'id': identifier, 'path': path, 'media_type': item.get('media-type')}
    spine = []
    for ref in spines[0].findall(ns + 'itemref'):
        check_cancelled(cancelled)
        item = items.get(ref.get('idref'))
        if item is None or item['media_type'] != 'application/xhtml+xml':
            raise SourceError('missing/unsupported spine target')
        spine.append({**item, 'occurrence': len(spine)})
    if not spine:
        raise SourceError('empty spine')
    metadata = package.find(ns + 'metadata')
    fixed = False if metadata is None else any(
        node.get('property') == 'rendition:layout' and node.text == 'pre-paginated'
        for node in metadata.findall(ns + 'meta'))
    return {'package_path': package_path, 'spine': spine, 'fixed_layout': fixed}
