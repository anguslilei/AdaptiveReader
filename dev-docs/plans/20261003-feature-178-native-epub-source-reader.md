# Feature #178 — native bounded EPUB source resource reader

Status: DONE after PR3 merge b0904eaae1572321c12b1ba9aa08b4b2199cd39f; Gate2 PASS2, Gate4 PASS3, foundational Gate5 passed. Baseline main95b5ec0 (PR #2→#1 merged at user request).
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
tests interrupt actual file reads and observe the actual deferred POSIX close status, once for the same fd, avoiding fd-reuse races.
These are test seams on the isolated loader, not a public fake byte-source path.
Resource cancellation tests cancel the calling task before the actual actor read.

## Native RED and implementation start

Own run37103962526 atc8bb313eac4189ff0df66785d21a1b7dd7c59984 compiles the
stub API/test harness with native Swift6, then29 tests fail74 assertions/errors
because behavior is unimplemented. No compiler-only RED is claimed. Native CI
is extended for this branch: select the simulator UDID, compile Debug/Release,
then boot the isolated simulator before tests,
record generated3.67.10 (1052), Debug/Release and existing+new suites through the
watchdog with aggregate xcresult checks. XML/OPF/CFI remain outside this WI.
Limits are immutable configuration; validate() runs at the actual open/load
boundary and allows only positive values up to defaults. Constructor itself is
nonthrowing so invalid user configuration can be exercised at that boundary.

## Implementation audit round1 corrections

Five Medium findings: reject fileURL NUL before CString; replace racy post-close
F_GETFD assertion with actual deferred-close callback; otherwise-valid embedded
local-header overlap fixture; CI requires passed xcresult nodes for all3 new
suites and zero skips; deterministic factory cancellation after worker start and
before publication, plus changed-during-read rejection. Internal Sendable load
observations are test synchronization seams; they do not supply alternate bytes
or bypass actual IO/inflate. Round2 independent implementation PASS, no open findings. Mac29 contracts GREEN at8e4f56e,
prior to these stronger regression tests; no iOS GREEN claim yet.


Updated Mac source7e19006ce44fdf9d0650e9e5e1781d2d9da68933, own run37105061416:
32 tests/3 suites pass including factory start/publication cancellation, actual
close observation, source mutation and valid-overlap rejection. This historical
Mac result is superseded by the final source validation below.

## Final platform correction and Gate5 evidence

Initial iOS validation of7e19006 built Debug/Release but failed one NUL-path
typed-error expectation. The diagnostic run atc546b9f exposed `.ioFailure`
instead of `.invalidSource` and hit its1200s deadline during xcresult finalization;
the incomplete bundle is not positive evidence. Source4264fee decodes the encoded
URL path once before NUL validation and uses that exact string in POSIX open.
Both NUL URL forms and a real space/CJK/literal `%00` filename are exercised.
Independent Gate4 round3 PASS, zero open findings. No round4 was needed.

CI uses regular-file wrapper capture, preserves exit status, retains the full raw
log and always harvests a completed result bundle. The isolated simulator boots
after compiler stages; test watchdog1800s and job75min bound cold-build overhead.
All compiler/test/result guards run. Final source4264feed0b360c5d2423ea227fc5ff3fa999c280:
Mac33 tests/3 suites pass (run37110508550); iOS126 distinct tests pass, zero
failures/skips, all three new suites explicitly Passed (run37110508591). Debug and
Release pass using actual generated3.67.10 (1052), Xcode26.3/XcodeGen2.46.0 on
iPhone17Pro iOS26.2. Parameterized device executions151 are not extra distinct
tests. Foundational Gate5 is satisfied by actual file/zlib integration and audit.
See [evidence](../verification/feature-178-20261003.md). Production semantic
reader wiring, real-book compatibility, XML/package/source-map/CFI and AI remain
separate work. The row stays IN PROGRESS until merge; no release/tag is created.
