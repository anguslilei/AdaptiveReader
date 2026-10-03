"""Bounded STORE/DEFLATE output, independently of advertised output length."""
import struct
import zipfile
import zlib
from errors import SourceError, check_cancelled


def extract_bytes(file, archive, entry, output_room, account, cancelled):
    # ZipFile validates local filename/header overlap; it does not prove complete
    # output when a forged central-directory length/CRC describes only a prefix.
    with archive.open(entry):
        pass
    file.seek(entry.header_offset)
    header = file.read(30)
    if len(header) != 30 or header[:4] != b'PK\x03\x04':
        raise SourceError('invalid local ZIP header')
    flags, method = struct.unpack_from('<HH', header, 6)
    if flags != entry.flag_bits or method != entry.compress_type:
        raise SourceError('local/central ZIP method or flags differ')
    name_size, extra_size = struct.unpack_from('<HH', header, 26)
    file.seek(entry.header_offset + 30 + name_size + extra_size)
    if method == zipfile.ZIP_STORED and entry.compress_size != entry.file_size:
        raise SourceError('stored ZIP sizes differ')
    decoder = zlib.decompressobj(-15) if method == zipfile.ZIP_DEFLATED else None
    remaining = entry.compress_size
    output = bytearray()
    crc = 0

    def emit(chunk):
        nonlocal crc
        room = output_room(len(output))
        account(len(chunk))
        if len(chunk) > room:
            raise SourceError('actual output byte budget exceeded')
        output.extend(chunk)
        crc = zlib.crc32(chunk, crc)

    while remaining:
        check_cancelled(cancelled)
        compressed = file.read(min(65536, remaining))
        if not compressed:
            raise SourceError('truncated compressed ZIP bytes')
        remaining -= len(compressed)
        if decoder is None:
            emit(compressed)
            continue
        pending = compressed
        while pending:
            check_cancelled(cancelled)
            # max_length bounds each Python-visible output allocation. The zlib
            # internal workspace is still not a native app memory guarantee.
            chunk = decoder.decompress(pending, max(1, output_room(len(output)) + 1))
            emit(chunk)
            pending = decoder.unconsumed_tail
            if decoder.unused_data:
                raise SourceError('trailing bytes after deflate stream')
    if decoder is not None and not decoder.eof:
        raise SourceError('incomplete deflate stream')
    if len(output) != entry.file_size or crc != entry.CRC:
        raise SourceError('ZIP output length/CRC mismatch')
    return bytes(output)
