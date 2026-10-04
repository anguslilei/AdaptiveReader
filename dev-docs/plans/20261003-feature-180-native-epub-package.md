# Feature180 — bounded native EPUB package and spine resolution

Status: IN PROGRESS; implementation and foundational integration pass, awaiting PR review/merge. Gate2 PASS2; Gate4 PASS3.
Prerequisites: feature178 and feature179 are merged/DONE; their APIs/contracts are unchanged from reviewed b0c0a249.
The Gate2 sections below record historical plan checkpoints; actual implementation evidence is appended at the end. Interfaces remain within the audited plan.

## Problem and scope

The native byte and XML utilities do not yet identify an EPUB package or its
ordered chapter references. Add a foundational package loader composing their
real APIs to read container.xml and the selected OPF, validate local manifest
references, and return an immutable package/spine DTO pinned to archive identity.
No chapter XHTML is loaded or semantically extracted in this WI. Repeated spine
references remain separate occurrences; auxiliary entries retain linear=false.

This is a bounded structural utility with explicitly limited URL/media support,
not an EPUB conformance validator or a claim of real-book compatibility. Repeated
spine references are preserved for source fidelity even though EPUB3.3 forbids
repeated idrefs; accepting these does not make the source publication conforming. No import/reader route, UI, AI, persistence,
Android, source-map/CFI/DOM selector, semantic block, metadata vocabulary/layout
interpretation, navigation/NCX, fallback rendering or media-overlay processing.
Package metadata may describe fixed layout; this utility neither determines nor
changes layout. Later extraction must make an explicit eligibility decision.

## Verified existing APIs and deliberate additions

At b0c0a249: EPUBSemanticResourceReader is an actor. Its open(fileURL:,
expectedArchiveSHA256:,limits:,observation:) async factory owns a bounded immutable
snapshot; read(path:) throws returns EPUBSemanticResource(path,bytes,sha256,
archiveSHA256), and close() is idempotent. It exposes no entry enumeration or
exists API. SemanticXMLParser.parse(Data,limits:,observation:) async returns
rootIndex/nodes/sourceSHA256 with expanded element names and lexical attributes.
Its strict UTF8/XML1.0, DTD rejection and unsupported representations apply here.
Project.yml sets Swift6.0; XcodeGen discovers sources/tests automatically.
There is no production caller for either utility; none is added by this plan.

Add a read-only catalog API rather than inflating every manifest resource to
check existence. Catalog contains only existing non-directory entry paths and
the snapshot digest, not bytes, descriptors or the mutable ZIP index. It is
bounded by the existing archive/entry limits, does no IO/inflate/hash work and
does not consume the reader's cumulative extraction budget. Returned path order
is literal UTF8 lexical order. Closed throws closed; cancellation closes the
reader and preserves CancellationError, consistent with read(path:).

## File-by-file surface and signatures

All new/changed Swift files stay under300 lines; estimated650–950 production and
450–700 test lines. Split proactively if implementation exceeds that estimate.
New package files under vreader/Services/Semantic/Package/:

- EPUBSemanticPackageTypes.swift: immutable Sendable DTOs. Package stores
  archiveSHA256, containerSHA256, packagePath, packageSHA256, manifestItems and
  spine. Manifest item stores id/path/mediaType/properties. Spine entry stores
  occurrence(zero-based array position), manifestIndex(valid index), linear Bool
  and properties; paths/IDs are obtained from manifestItems, with no deduplication
  of itemrefs. No generated stable semantic ID or chapter digest is invented.
  Typed package errors: invalidLimits, invalidContainer, invalidPackage,
  unsupportedPackage, unsupportedReference, unsafePath, missingResource,
  duplicateManifestID, duplicateResourcePath, invalidSpine, metadataLimit,
  inconsistentSource. Existing source/XML errors and CancellationError propagate.
- EPUBSemanticPackageLimits.swift: positive lowerable hard ceilings, defaults
  manifestItems4096, spineEntries4096, propertiesPerItem64, retainedUTF16=2Mi.
  Retained units include packagePath and all manifest/spine retained strings,
  including property tokens and media types, charging every DTO field occurrence
  even when String storage shares bytes. Catalog lookup path units have a separate
  lowerable2Mi ceiling before building its lookup map. Existing source/XML limits
  remain independently validated; no maximum is silently enlarged.
- EPUBPackageLiteralKey.swift: internal Hashable string key using literal UTF8
  equality/hash for IDs and resource paths. No Swift canonical-equivalence lookup
  may substitute another manifest ID or archive filename. DTO spelling is intact.
- EPUBPackageReference.swift: pure rootfilePath(_:) and resolve(href:packagePath:)
  functions implement the explicit local subset below. No URL/NSURL/file-system
  resolution, network loading or normalization of Unicode/case. rootfilePath uses
  the same strict decode-once rules with an empty archive-root base.
- EPUBPackageXMLAccess.swift: pure bounded tree helpers for immediate children,
  expanded-name matching using literal URI identity, required unqualified
  attributes, XML-whitespace token lists, budget checks and cancellation checks.
  Ignore text/comment/PI when looking for structural element children. Never
  search descendants to fabricate a missing direct wrapper. Reject xml:base on
  any element in either document; XInclude is unsupported, never fetched.
- EPUBContainerDecoder.swift: decode(document:catalog:limits:) throws -> String
  for the selected package path; exact structural/namespace rules below.
- EPUBPackageDecoder.swift: decode(document:packagePath:catalog:limits:) throws
  -> ordered manifest/spine parts, before assembling the final digest DTO.
- EPUBSemanticPackageLoader.swift: static load(fileURL:,expectedArchiveSHA256:
  String?=nil,sourceLimits:EPUBSemanticLimits,xmlLimits:SemanticXMLLimits,
  packageLimits:EPUBSemanticPackageLimits,observation:EPUBPackageLoadObservation?)
  async throws -> EPUBSemanticPackage. All limit objects validated before open.
  One detached worker owns orchestration/drafts; parent cancellation forwards.
  Worker opens the real source reader, queries catalog, reads/parses container,
  reads/parses OPF, validates/assembles, closes reader on every success/error/
  cancellation path, and only then publishes. Hashes returned by both resources,
  catalog and parsed documents must agree. No partially validated DTO escapes.
  Internal Sendable observation gates worker-start, reader-created, before-stage,
  before-publication and cancellation-forwarded for real lifecycle tests; they
  never substitute data, catalog, parser, errors or success. Concrete callbacks:
  workerStarted/beforePublication/cancellationForwarded are @Sendable () -> Void;
  readerCreated is @Sendable (EPUBSemanticResourceReader) -> Void; beforeStage is
  @Sendable (EPUBPackageStage) -> Void. Stage enum covers containerDecoded,
  opfDecoded, manifestItem(Int) and spineEntry(Int); real Task.checkCancellation
  runs before/after callbacks and every iteration. Defaults are no-op. Explicit
  do/catch awaits reader.close() on every post-open exit; no async defer syntax. A reader-created hook
  may retain the actual actor in a synchronized test probe to assert it is closed.

Changes to existing EPUB files (after prerequisite merge only):
- EPUBSemanticSourceTypes.swift: add EPUBSemanticResourceCatalog(archiveSHA256,
  paths:[String]) Sendable DTO.
- EPUBSemanticResourceReader.swift: catalog() throws -> that DTO; preserve open,
  read, snapshot, indexing, inflate, close and existing error contracts.

Tests under vreaderTests/Services/Semantic/Package/: EPUBPackageReferenceTests,
EPUBPackageDecoderTests, EPUBPackageLoaderTests. Catalog behavior tests may live
in the loader suite to avoid changing old semantic suites. Helpers use existing
EPUBSemanticZIPFixture ZIP builder and a bounded synchronized package probe (<300lines).
scripts/test-epub-package-contract.sh copies exact EPUB+XML+Package sources and
all three package suites into native Swift6 SwiftPM with CryptoKit/Foundation/
zlib (linkedLibrary("z")) as in the existing source harness. No remote dependency download.
New Mac workflow plus native-reader-check.yml branch/suite filters require all
nine EPUB/XML/Package Passed suite nodes, actual positive counts, failed0/skipped0,
original command status/full log/completed bundle, isolated simulator and both
Debug/Release compilers. Candidate final version3.67.12(1054), actual passing
XcodeGen pair copied unchanged in the final two-file generation/version commit.

OUT: existing EPUBParser, ZIPReader, reader hosts, BookRecord/locators, provider
and import flows, renderer/AI/UI, app schema, Android, existing inflate/index
algorithms and feature177 Python implementation. Docs/architecture/README/tracker
sync describe only implemented utility scope when its implementation PR opens.

## Container/package structural subset

- Container root expanded name is container namespace + container, version1.0.
  Exactly one immediate rootfiles and exactly one rootfile in that namespace;
  rootfile media-type exactly application/oebps-package+xml. Reject missing,
  ambiguous/multiple-rendition roots. full-path is an OCF root-relative URL
  reference: apply the same supported percent-decode-once rules with empty base,
  never relative to META-INF. The decoded result is a literal archive path.
  Validate safe components and exact non-directory catalog membership.
- OPF root is http://www.idpf.org/2007/opf + package, version2.0 or3.0. Exactly
  one immediate manifest and spine in that namespace; both nonempty. Optional
  metadata/other extension elements are not interpreted; this is not full schema
  validation. Namespaced attribute lookalikes cannot replace id/href/media-type.
- Each immediate manifest item requires one nonempty id token, local href and
  media-type. IDs/idrefs are opaque nonempty tokens without XML whitespace or
  controls, not a new full NCName validator. Compare literal UTF8; distinct NFC/
  NFD identifiers stay distinct. Duplicate ID or resolved resource path rejects.
  Every item must resolve to an exact catalog file, including non-spine assets;
  no inflate is performed for existence checks. Fallback attributes are explicitly
  unsupported; external/data references and fallback graphs are not resolved.
- Media-type must be two nonempty ASCII token components separated by one slash,
  no parameters/whitespace. Preserve spelling; ASCII case-insensitive comparison
  recognizes application/xhtml+xml. Non-spine asset media types may be other
  valid tokens; all referenced spine targets must be XHTML. SVG/foreign spine and
  any fallback attribute (including empty) rejects as unsupportedPackage, without
  guessing chains.
- Spine keeps every immediate itemref in order. idref resolves by literal ID;
  linear missing/yes means true, no means false, any other value rejects.
  Require at least one linear entry. Repeated references remain distinct
  occurrences; auxiliary entries are not removed. properties are XML-whitespace
  token lists, retain ordered tokens; each manifest item/itemref cap64. Duplicate
  tokens with literal UTF8 identity reject rather than quietly normalizing
  metadata; canonical-equivalent distinct opaque tokens are preserved. No vocabulary
  or layout semantics are inferred from those tokens.

## Local reference subset and source identity

Manifest href is relative to the OPF parent directory. Reject empty references,
absolute/network paths, schemes, any colon, backslash, queries/fragments, ASCII
controls/DEL and leading/trailing XML whitespace; embedded spaces/CJK/Unicode
remain literal. Percent escapes require exactly two hex digits and strict UTF8
decoding once. Apply colon/control/delimiter bans to decoded text too; encoded
colon is unsupported just like raw colon. Reject encoded slash/backslash/query/
fragment/NUL, and any decoded
percent followed by two hex digits (unsupported double encoding). No further
decode or Unicode normalization. Encoded controls fail after decode.

Before component normalization, reject terminal decoded dot/dotdot components
(including percent-encoded forms); their directory intent must not be changed
into a matching ZIP file. Normalize other complete decoded dot segments by an explicit component stack relative
to the validated OPF parent; parent movement within the archive is allowed, escape
above archive root is rejected. Reject empty components/repeated/trailing slash
and empty final file path. Validate final path with existing safe archive-path
rules, then exact literal catalog membership. Case/NFC/NFD lookalikes never match.
Rootfile URLs and href URLs both decode once; %25 may resolve to a literal '%'
filename if it does not create another valid escape. An actual filename containing
a literal percent followed by hex digits is unsupported by this strict subset;
never guess another decoding round. Only decode the incoming reference, never
the already-decoded literal OPF base path. All hashes refer to original bytes, not XML
serialization or package text. A later chapter read must reopen against this
archiveSHA256 to reject a changed revision; no chapter identity is claimed here.

## Sequencing and dependencies

One coherent foundational WI: Gate1 plan → independent Gate2(max3) → wait for
178+179 merged/DONE → native compile-capable behavioral RED → GREEN → independent
Gate4(max3) → actual Mac/iOS integration/compiler evidence → docs → generation/
version tail → implementation PR. Catalog, URI and decoder tests are internal
steps of the same WI; no premature tracker-only implementation PR.
All Gate3 source/test/harness changes are blocked now by rule48. Planning/audit
can be committed on feature/180-native-epub-package based on b0c0a249 without
altering PR3/4. Before implementation, reconcile onto merged main, update tracker
prerequisites truthfully and rerun Gate2 if interfaces/contracts changed.
User permits dev-branch commits/PR creation; current PR3/4 merges need explicit
authorization, because prior merge instruction concerned PR1/2. No release/tag.

## Concrete test catalogue / real integration

- Catalog: ordered exact file-only paths, original archive hash, no byte budget
  consumption across repeated queries, invalid/closed/cancelled reader behavior;
  cancelled catalog closes, no mutable index/descriptor exposure.
- Container: correct prefixed/default namespace, top-level comment/PI, exact
  direct wrapper; missing/duplicate/nested/spoofed rootfiles/rootfile, versions,
  wrong media/namespace, raw/encoded CJK and escaped percent full-path, root-relative
  resolution versus META-INF, literal-percent-hex-name rejection, absent/directory package,
  xml:base and XInclude rejection. Legacy Python's missing-version fixture is
  NOT native conformance evidence; new fixtures include explicit versions.
- OPF:2.0/3.0, unique ordered manifest, repeated spine IDs, linear defaults/no,
  all-no/empty/unknown idref/invalid linear; duplicate IDs/normalized path aliases,
  wrong/missing/nested wrapper, namespaced attribute spoofing, unsupported fallback
  and SVG/foreign target; assets exist without extraction, budgets would fail if
  an implementation tried to read them. Media-type casing/token errors, properties
  exact/over count and duplicate tokens, metadata extension not interpreted.
- URI: root-level OPF, sibling/subdir/in-root parent/escape, '.'/'..' complete
  segments; terminal '.', '..', 'child/..' and encoded variants with matching
  archive file entries to prove directory rejection, malformed/mixed-case escapes,
  encoded delimiter/control/colon(%3A/%3a), invalid UTF8,
  schemes/data/file/http/network/query/fragment/drive path/colon/backslash/repeated
  slash/trailing slash; percent-parent and literal percent base are not decoded
  twice; raw and encoded CJK/emoji/RTL/combining names, exact Unicode/case lookup,
  canonical-equivalent distinct IDs do not collide or match the wrong target.
- Budgets: zero/negative/Int.max and default+1 invalid configuration before open;
  exact/over manifest/spine/properties/DTO payload/catalog-key bounds, repeated
  itemref accounting and long Unicode property/path values. Source/XML caps,
  unsupported encoding/DTD/namespace and actual CRC errors propagate intact.
- Lifecycle: cancellation before open, after real reader creation, between
  container/OPF stages, during actual decoder iteration, after fully built DTO
  before publication; forward real task cancellation, assert actual reader closed
  via subsequent catalog/read, never publish. Deterministic bounded semaphores5s,
  no timing sleeps/fake bytes. Concurrent independent loads do not share budgets.
- Integration: real temporary stored/deflated archives using production reader
  and parser. Known independent container/OPF/archive hashes; corrupt/missing OPF
  after valid container; replaced source path while snapshot exists remains pinned;
  subsequent load with old expected digest rejects. No mock reader/parser/catalog.

CI/exact-structure fixtures are the documented synthetic exception; test-books/
is absent in this workspace, so no real-book compatibility claim. Foundational
Gate5 uses native real-subsystem integration/audit with Mac and isolated iPhone17
Pro tests plus Debug/Release. All3 new suites must have explicit Passed nodes;
zero skips/failed, nonempty counts and actual command status. Preserve existing
guards and source/generation/tool evidence; no unfinished run reported GREEN.

## Prior art / rejected alternatives / risks

Primary research: W3C EPUB3.3 Recommendation2026-01-13, container/file-path,
package URL and spine sections; RFC3986 path/percent/dot segments. Native scope is
an explicitly smaller local subset, NOT implementation of the complete WHATWG
URL/EPUB validator algorithms. No broad standards-compatibility assertion.
https://www.w3.org/TR/2026/REC-epub-33-20260113/#sec-container-metainf-container.xml
https://www.w3.org/TR/epub-33/#sec-package-doc
https://www.w3.org/TR/epub-33/#sec-spine-elem
https://www.rfc-editor.org/rfc/rfc3986.html#section-5.2.4
Project precedent: feature177 package_manifest.py's bounded local subset and
explicit rejection; feature178 immutable resource identity/budgets; feature179
actual Foundation namespace fidelity and strict unsupported representations.
Differences are deliberate: both rootfile and manifest URL strings decode once
with different bases; version checks and linear retention added; IDs/paths use
literal identity; duplicate path rejection. Repeated idrefs are deliberate source-
fidelity tolerance of nonconforming input, not EPUB3.3 conformance.

Reject reusing legacy EPUBParser/String/cache or ZIPReader, read-every-asset
existence validation, metadata descendant search, Foundation URL convenience
normalization and silently choosing fallback/rendition. Reader catalog is the
small necessary extension, not exposing internals. UTF16 and DTD books remain
unsupported through feature179; other supported-subset rejections may limit
real-book coverage. Bounded snapshot/XML/input/DTO/catalog maps bound memory, not
an exact heap/CPU guarantee. Cooperative cancellation includes parser/scan/loop
checkpoints, not interruption of a single token or hash operation. No schema/
backup migration or externally visible change; integration remains a later WI.

## Acceptance

Behavioral native RED compiles then fails on the unimplemented contract. GREEN
returns deterministic immutable digest-pinned package/order without reading
asset/chapter bytes. All rejection, bounds, literal identity, resource lifecycle
and cancellation cases pass through real source/XML components. Mac/iOS3 new
suites explicitly pass; Debug/Release pass; zero open auditCritical/High/Medium.
Docs sync and actual generated pair tail before PR. Feature remains unmerged
until implementation lands; plan-only completion does not claim delivered code.

## Gate2 round1 corrections / author research correction

Auditor Medium: terminal decoded dot segments lost directory intent; reject them
before normalization and test catalog collisions. Auditor Low: encoded colon ban
ambiguous; decoded colons now explicitly rejected/tested. Optional property-token
identity refinement accepted: literal UTF8 duplicate checks. No audit remedy rejected.

Author's direct W3C REC2026-01-13 reading disproved the initial rootfile-literal
assumption (sec4.2.6.3.1.3 says full-path is a path-relative-scheme-less URL), including
the initial auditor's matching confirmation. Decode once relative to archive root,
with fixtures, never META-INF. W3C sec5.7.2 forbids repeated idrefs in conforming
EPUB3.3; the project's existing source-fidelity repetition policy is retained but
explicitly described as accepting nonconforming input, not a conformance claim.
These primary-source corrections require round2 independent review. No runtime
measurement yet; Gate3 remains blocked by unmerged prerequisites.

## Gate2 round2 PASS

Independent read-only rereview passes with zero open findings. Terminal-directory
intent, raw/decoded colon restrictions, rootfile URL semantics, deliberate repeated
idref preservation, literal property-token identity and actual lifecycle cleanup
are explicit. Source/API/wiring, finite independent budgets, non-inflating catalog,
digest identity and WI cohesion confirmed. See committed plan audit for every
finding/disposition and primary-source-disproven assumption. No code/tests/builds
or feature180 runtime evidence exist yet; Gate3 waits for178+179 merged/DONE.

## Prerequisites resolved2026-10-03

User explicitly approved merging PR3/4. PR3 merged b0904eaae1572321c12b1ba9aa08b4b2199cd39f,
PR4 retargeted main and merged55719b27c62c0f0d37556618d4525a0ea8e1135e. Exact heads
had passing final native/compiler/reference/Mac checks; merged tree equals reviewed
b0c0a249 tree. Feature178/179 marked DONE in this reconciliation commit. Interfaces
unchanged, Gate2 PASS2 remains applicable. Gate3 may proceed; no release/tag made.


## Implementation and verification2026-10-04

Functional source40af655; final independently audited harness fda86fbb.
Native behavioral RED/GREEN and Unicode/property/literal-equality regressions are
recorded with immutable run/source identities in
[verification](../verification/feature-180-20261004.md).
Initial stub RED25 tests/83 issues; scalar RED28/3 issues; audit RED30/6 issues.
Corrected source Mac30 tests/3 suites passes. Final rerun37160519904 also passes30;
reference regression43 and preparation compiler run37160519891 succeed.

Gate4 round1 FAIL: Medium property-cap trailing whitespace; Low canonical DTO
equality. Both confirmed by actual native RED then corrected; round2 PASS.
Round3 reviews only sequential native lane ownership and bounded own-CI evidence
export; PASS with zero open findings. Source and tests unchanged from40af655.
All findings/dispositions and rejected/disproven assumptions are enumerated in
[Gate4 audit](../../.claude/codex-audits/feature-180-gate4-audit.md). No remedy rejected.

Initial combined native run37157905091 passed Debug/Release but failed2 observer
start assertions. Cooperative-pool contention is an inference; no production
defect claim, omitted tests or relaxed deadlines. Final sequential native
run37160519963 build/test steps pass 155 base +30 package distinct tests in separate
completed bundles, all nine semantic suites explicitly Passed, failed/skipped0,
and Debug/Release succeed. Original watchdog wrapper and same isolated UDID used.

Real ZIP/XML deterministic fixtures use the explicit CI/exact-structure exception;
no real-book or production reachability claim. Rule47 foundational integration is
satisfied by real source/XML integration/native tests/audit. Chapter extraction,
semantic blocks/source map, production import/renderer/UI/AI remain later WIs.

Actual XcodeGen-generated3.67.12(1054) project.yml/PBX pair from the passing own run is
copied exactly as the last two-file version commit. Local workspace went offline;
selected evidence text was recovered via the fixed own-CI exporter and independently
byte/SHA256/Gitblob verified. Artifact ZIP digest is GitHub metadata, not a claim of
local download/unpack verification. See evidence manifest for exact provenance.

Tracker remains IN PROGRESS until merge, then DONE; no VERIFIED/release/tag.
Issues are disabled, so no fabricated GitHub issue reference. User authorization
covers development-branch commits and PR creation; PR5 merge awaits authorization.


Post-audit correction: native run37160519963 passed both compilers and155+30
real tests, but its exporter failed an unmatched Python parenthesis. A single
trailing parenthesis was removed and verified in own recovery CI at
1f97fa8daed2bfd27be56fa4bc04a210877bb667 (run37162305962). No application/test changes. Gate4 PASS3
is historical atfda86fbb; no fourth audit was run. Rule47's three-round ceiling
requires escalation, so the PR is a draft with this post-audit correction pending
explicit acceptance before merge. Evidence is partial; no VERIFIED claim.
