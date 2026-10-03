# Feature #178 — native bounded EPUB source resource reader

Status: PLANNED, Gate 2 PASS after 2 rounds. Baseline main95b5ec0 (PR #2→#1 merged at user request).
Feature177 now merged; its reference algorithms and both compiler fixes are on main.

## Problem / scope

The future SemanticDocument layer needs original archive/resource bytes and
SHA-256 revision identity. EPUBParserProtocol returns String; legacy ZIPReader
silently collapses duplicate paths, does not verify CRC/local metadata, and grows
its inflate buffer. Those APIs cannot establish this new contract. This WI adds
an independent foundational utility, not a production reader route. No extraction,
XML/encoding decoding, OPF/spine/href resolution, CFI, UI, network, AI, persistence,
Android, or changes to existing EPUBParser/ZIPReader/renderer are included.

## Files and signatures

New directory vreader/Services/Semantic/EPUB/ (all files <300 lines):
- EPUBSemanticSourceTypes.swift: immutable Sendable limits (validated positive, lowerable hard ceilings:
  archive64MiB, entries4096, compressed8MiB, resource4MiB, total16MiB, ratio200);
  immutable resource Data/path/resourceSHA/archiveSHA; typed error enum.
- EPUBSourceSnapshot.swift: load(URL, limits, expectedArchiveSHA256: String?)
  throws -> bounded immutable Data + digest (synchronous worker called in detached task). Darwin.open(O_RDONLY|O_NONBLOCK|O_NOFOLLOW|O_CLOEXEC), fstat regular-file
  guard before wrapping one FileHandle, close in defer; fstat before/after (device/inode/size/mtime/ctime); 64KiB reads,
  actual byte ceiling and Task.checkCancellation each chunk. Reject non-regular
  sources, invalid expected digests, changed-during-read source. Snapshot remains
  valid if the path later changes: intentional difference from prototype's live
  FD session, no subsequent path reopen or renderer cache lookup.
- EPUBSourceZIPIndex.swift: validated classic single-disk ZIP index from snapshot,
  exact central/local metadata/filename agreement, stored/deflate only, CRC,
  signed/unsigned data-descriptor verification, nonoverlapping local ranges.
  Reject ZIP64, encryption/unsupported flags, symlinks, malformed extras, invalid
  lengths/counts/sizes, duplicate or Unicode-equivalent paths and unsafe paths.
  UTF8-flag names decode strictly; without flag ASCII only (no CP437 guessing).
- EPUBSourceZIPBytes.swift: overflow-safe bounded little-endian reads, strict
  path and extra-field helpers; no unaligned loads or imported legacy helpers.
- EPUBSourceInflater.swift: system zlib raw DEFLATE via inflateInit2_(-MAX_WBITS),
  32KiB output scratch, check actual resource/remaining-total/ratio budget before
  publishing chunks. Require STREAM_END + all compressed input consumed, exact
  declared decompressed size, CRC32 (stored too), cancellation each iteration.
- EPUBSemanticResourceReader.swift: actor; static open(fileURL:expectedArchiveSHA256:
  limits:) async throws -> reader; read(path:) throws -> resource; close() idempotent.
  Aggregate counts repeated successful reads; failed/cancelled reads terminate
  the session and release snapshot, no partial resource publication. No cache.
  Parsing/read operations do not suspend inside actor (no reentrant race).

Tests vreaderTests/Services/Semantic/EPUB/: EPUBSemanticResourceReaderTests.swift,
EPUBSourceZIPValidationTests.swift, EPUBSourceBudgetTests.swift plus a bounded
local-fixture builder under Helpers (stored + fixed Python-produced raw-deflate
bytes, CRC/metadata mutation support). Tests use actual files and actual reader,
not mock byte-source acceptance. Tiny deterministic fixtures are the CI/exact
structure exception; no real-book compatibility/performance claim.

scripts/test-epub-source-contract.sh copies these exact production/test sources
into a temporary SwiftPM vreader module, Swift6 strict concurrency, system zlib
and CryptoKit, for fast macOS RED/GREEN independent of the existing huge app test
target. CI also generates and builds iOS Debug/Release, and runs the same new
suites through scripts/run-tests.sh on an isolated simulator, checking xcresult
positive executed counts/zero failures. Record source/version/generator provenance.
No copied source is checked in, no dependency download, signing or release.

Docs: architecture/README/adaptive-reader contract gain accurate utility status;
feature177 DONE + bug376 FIXED records finalized using merged main SHA/evidence.
New feature178 remains IN PROGRESS until its PR merges. Disabled Issues410 remains
recorded; no fabricated issue or settings changes. Final version pair3.67.10
(1052) is actual XcodeGen output committed last before PR.

## Precedent / alternatives

Feature177 verified original-byte revision and bounded extraction concepts.
ZIPReader actor is isolation precedent only; do not extend its weak trust model
or change legacy reading behavior. Snapshot64MiB bound trades memory for immutable
identity, so there is no lifetime file handle or live-path revision race after
open. This is a documented experimental ceiling, not production library policy.
System zlib supports raw DEFLATE and caller-provided output buffers; explicit CRC
is required for ZIP. Primary reference: https://zlib.net/manual.html . Platform
import/link feasibility is proven by Mac and iOS builds, not inferred.

Rejected: renderer String cache (no bytes), one-shot Compression.decode_buffer
(no verified stream end/input consumption), a new ZIP package (unnecessary
shipped dependency for this bounded classic-ZIP subset), full XML/DOM port in this
PR (separate Gate2 plan once bytes contract is merged).

## WI / gates

Single foundational WI: independent plan audit → executable native RED with
compilable unimplemented API → bounded implementation/GREEN → independent
implementation audit → iOS Debug/Release + real reader tests → final generated
version pair → PR. User explicitly authorized current merges, continued branch
commits and PRs; no release or future PR merge is implied.

## Test catalogue / acceptance

Original stored/deflated/empty/Unicode bytes and SHA known values; expected digest
mismatch/malformed digest; same-name same-size changed bytes differ; source path
replacement after open retains pinned snapshot; two independent sessions; repeated
read aggregate charging; zero/negative/extreme limits fail safely; open/read
cancellation; failure closes actor; repeated close/post-close; truncated EOCD/CD/
local header, false EOCD inside comment, wrong disk/count/CD bounds; duplicate
NFC/NFD/path traversal/backslash/NUL/absolute/drive/empty components; encrypted,
unsupported flags/method, ZIP64/symlink/malformed extras; local/central name/flags/
method/CRC/size disagreement; signed/unsigned/missing/corrupt descriptors; overlaps;
wrong CRC, dishonest output lengths/ratio, truncated/garbage/trailing deflate;
actual decompression and cumulative ceilings (including repeated reads).

Acceptance: all new tests GREEN after captured native behavioral RED; snapshots
and resource digests independently checked; no partial publication; finite bounds
and cancellation observed; Mac/system-zlib and actual iOS builds/tests recorded;
no open Critical/High/Medium audit findings; version-only tail from verified
XcodeGen artifact. Foundation Gate5 uses real-file integration tests + audit;
no user-visible reader wiring, actual source maps or production book support is
claimed. Existing data/locators/reader output are unchanged; no migration.

## Risks / limitations

Snapshot heap retains up to archive ceiling, plus bounded compressed/output/scratch
buffers. Strict ZIP subset intentionally rejects CP437/ZIP64/encrypted/symlink
inputs and ambiguous paths; future book-corpus evidence may expand compatibility
without weakening limits. SHA verifies exact observed snapshot, not publisher
provenance. Cancellation is cooperative per chunk/entry/inflate call; no hard CPU
latency guarantee. Open explicitly uses a detached load task; a cancellation handler forwards parent
cancellation and checks cancellation before actor publication. No UI call site
is introduced. Limits only lower default hard ceilings, keeping Int/uInt arithmetic
bounded. Directories require zero declared sizes. Descriptor parsing compares
full values and supports an unsigned descriptor whose CRC equals signature magic.

## Gate2 corrections — binary grammar and audit round1

Primary ZIP specification: https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT
Classic single-disk EOCD comment must end at snapshot EOF; directory offset+size
must equal EOCD offset, exactly declared record count consumes entire directory.
Unknown flags rejected: allowed0x0808 stored (UTF8 + descriptor), allowed0x080E
DEFLATE (plus option bits1/2). Local flags/method/name exactly match central.
For bit3 local CRC/sizes must be zero or central-equal; signed/unsigned descriptor
must match central CRC + compressed + decompressed sizes in full. No guessed
size from local placeholders. No descriptor is searched inside compressed bytes.
Reject ZIP64 extra0x0001 and path/encoding-altering extras0x7075/0x0008 (including
unknown Unicode-path version), plus malformed TLV; unknown nonpath metadata stays
inert. Local extras follow the same policy. Directory names end slash, payload
must be zero-size stored and CRC0. All local header/data/descriptor spans end
before central directory and are sorted to reject overlap. Unreferenced gaps are
inert bytes; no executable/extraction operation. EOCD search checks cancellation
periodically; entry/name/extra/index passes remain bounded by archive/entry caps.
Round1 auditor requested FIFO-safe open, explicit executor/cancellation ownership,
finite hard ceilings and binary grammar/spec clarity; corrections above and in
snapshot/limits section are applied. Round2 PASS, no open findings; see .claude/codex-audits/plan-feature-178-gate2-audit.md.

## Gate2 executable refinements / sizing

WI estimate: six focused production files (~650–900 lines combined), three test
suites + shared fixture helper (~450–650 lines), tooling/workflow/docs (~150 lines).
One coherent reader boundary; if implementation exceeds these bounds, split a
separate WI rather than pull in XML/manifest parsing.
Explicit tests include directory/FIFO/final-symlink source rejection, cancelled
parent publication, deterministic mid-load cancellation with descriptor cleanup,
and unsigned descriptor CRC equal to0x08074b50. Snapshot has internal synchronous
checkCancellation/descriptorObserved closures with real production defaults;
tests interrupt actual file reads and confirm observed fd is EBADF afterward.
These are test seams on the isolated loader, not a public fake byte-source path.
Resource cancellation tests cancel the calling task before the actual actor read.
