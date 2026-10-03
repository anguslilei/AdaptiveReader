"""Bounded, synchronous original-byte reader; never uses the app renderer cache."""
from contextlib import contextmanager
from dataclasses import dataclass
import hashlib
import os
from pathlib import Path
import re
import stat
import threading
import zipfile
from errors import SourceError, check_cancelled

@dataclass(frozen=True)
class Limits:
    archive_bytes: int = 64 * 1024 * 1024
    entries: int = 4096
    compressed_bytes: int = 8 * 1024 * 1024
    resource_bytes: int = 4 * 1024 * 1024
    total_bytes: int = 16 * 1024 * 1024
    ratio: int = 200
    xml_nodes: int = 50000
    xml_depth: int = 96

    def __post_init__(self):
        if any(type(v) is not int or v <= 0 for v in vars(self).values()):
            raise SourceError('limits must be positive integers')

@dataclass(frozen=True)
class SourceResource:
    path: str
    data: bytes
    sha256: str
    archive_sha256: str


def safe_entry_path(name):
    candidate = name[:-1] if name.endswith('/') else name
    if (not candidate or '\\' in name or '\x00' in name or name.startswith('/')
            or re.match(r'^[A-Za-z]:', name)
            or any(p in ('', '.', '..') for p in candidate.split('/'))):
        raise SourceError('unsafe archive path')
    return name


class EpubSourceReader:
    """Owner-thread session. Failed read terminates it; close is idempotent."""
    def __init__(self, path, expected_sha256=None, limits=Limits(), cancelled=lambda: False):
        self.path = Path(path)
        self.limits = limits
        self.cancelled = cancelled
        self._owner = threading.get_ident()
        self._busy = True
        self._file = None
        self._zip = None
        self.closed = False
        self.total = 0
        self._entered = False
        try:
            check_cancelled(cancelled)
            self._file = self.path.open('rb')
            self._identity = self._snapshot(os.fstat(self._file.fileno()))
            if self._identity[2] > limits.archive_bytes:
                raise SourceError('archive byte limit exceeded')
            digest = hashlib.sha256()
            while chunk := self._file.read(65536):
                check_cancelled(cancelled)
                digest.update(chunk)
            self.archive_sha256 = digest.hexdigest()
            if expected_sha256 is not None and expected_sha256 != self.archive_sha256:
                raise SourceError('source SHA-256 mismatch')
            self._unchanged()
            self._file.seek(0)
            self._zip = zipfile.ZipFile(self._file)
            entries = self._zip.infolist()
            if len(entries) > limits.entries:
                raise SourceError('entry count limit exceeded')
            self._entries = {}
            for entry in entries:
                check_cancelled(cancelled)
                safe_entry_path(entry.filename)
                if entry.filename in self._entries:
                    raise SourceError('duplicate ZIP entry')
                if stat.S_ISLNK(entry.external_attr >> 16):
                    raise SourceError('symlink ZIP entry')
                if entry.flag_bits & 1 or entry.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
                    raise SourceError('encrypted/unsupported ZIP entry')
                if entry.compress_size > limits.compressed_bytes or entry.file_size > limits.resource_bytes:
                    raise SourceError('entry size limit exceeded')
                if entry.file_size > max(1, entry.compress_size) * limits.ratio:
                    raise SourceError('entry expansion ratio exceeded')
                self._entries[entry.filename] = entry
            self._unchanged()
        except BaseException as exc:
            self._close_internal()
            if isinstance(exc, (SourceError, KeyboardInterrupt, SystemExit)):
                raise
            raise SourceError(f'cannot open EPUB: {exc}') from exc
        finally:
            self._busy = False

    @staticmethod
    def _snapshot(s):
        return s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns, s.st_ctime_ns

    def _unchanged(self):
        if (self._snapshot(os.fstat(self._file.fileno())) != self._identity
                or self._snapshot(self.path.stat()) != self._identity):
            raise SourceError('source file changed or replaced')

    def _owner_check(self):
        if threading.get_ident() != self._owner:
            raise SourceError('reader belongs to another thread')

    @contextmanager
    def _operation(self):
        self._owner_check()
        if self.closed or self._busy:
            raise SourceError('reader closed or reentrant operation')
        self._busy = True
        try:
            check_cancelled(self.cancelled)
            self._unchanged()
            yield
            self._unchanged()
        except BaseException as exc:
            self._close_internal()
            if isinstance(exc, (SourceError, KeyboardInterrupt, SystemExit)):
                raise
            raise SourceError(f'cannot read EPUB: {exc}') from exc
        finally:
            self._busy = False

    def _read(self, path):
        safe_entry_path(path)
        entry = self._entries.get(path)
        if entry is None or entry.is_dir():
            raise SourceError('missing resource: ' + path)
        from zip_stream import extract_bytes
        def room(size):
            return min(self.limits.resource_bytes - size, self.limits.total_bytes - self.total)
        def account(size):
            self.total += size
        data = extract_bytes(self._file, self._zip, entry, room, account, self.cancelled)
        return SourceResource(path, data, hashlib.sha256(data).hexdigest(), self.archive_sha256)

    def read(self, path):
        with self._operation():
            return self._read(path)

    def manifest(self):
        from package_manifest import read_manifest
        with self._operation():
            return read_manifest(self._read, self._entries, self.limits, self.cancelled)

    def _close_internal(self):
        self.closed = True
        try:
            if self._zip is not None:
                self._zip.close()
        finally:
            if self._file is not None:
                self._file.close()

    def close(self):
        self._owner_check()
        if self._busy:
            raise SourceError('cannot close during operation')
        self._close_internal()

    def __enter__(self):
        self._owner_check()
        if self.closed or self._busy or self._entered:
            raise SourceError('cannot enter closed/busy/nested reader')
        self._entered = True
        return self

    def __exit__(self, *_):
        self.close()
