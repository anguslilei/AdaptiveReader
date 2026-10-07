# Feature 182 — bounded single-resource XHTML semantic extraction

Status: PLANNED; Gate 1 complete, independent Gate 2 PASS in two rounds. ID reserved using
`scripts/reserve-id.sh feature` on 2026-10-07. Branch
`codex/bounded-xhtml-semantics` starts at main bfe162c8 (PR #6, 3.67.13/1055).
Dependencies 178–181 are DONE. One foundational WI / one PR; no merge authorized.

## Problem and boundary

The native source, XML and identity foundations cannot yet describe a chapter's
semantic structure. Add an opt-in in-memory extractor for exactly one original
XHTML resource, with explicit finite budgets and deterministic source-bound output.
No production caller, full book/document builder, archive session, package loader
extension, renderer, UI, AI, CSS evaluation, network fetch, persistence, source
resolver, normalized text map, byte map, XPath or CFI. This is a logical-tree
structural subset, not HTML conformance, rendered text or exact navigation.

The caller supplies one `EPUBSemanticResource` from the existing bounded reader
and a spine occurrence. Its archive digest is a caller provenance assertion;
the extractor checks digest spelling and recomputes the resource digest from the
actual bytes. It cannot prove archive membership or spine membership from a DTO.
Integration tests compose the real reader/package loader to establish that path.
No caller-supplied XMLDocument or extractor version is accepted. Policy version
is a fixed constant 1; future policy changes must increment it.

## Prior art / existing contracts / rejected alternatives

- W3C EPUB 3.3 XHTML content documents: https://www.w3.org/TR/epub-33/#sec-xhtml
  motivates namespace-sensitive XHTML processing; this subset keeps strict XML.
- W3C XML 1.0 sections 2.10/2.11: https://www.w3.org/TR/xml/
  distinguishes logical parser text (including newline/entity processing) from
  original bytes. Preserve parser text, without claiming byte-perfect ranges.
- Existing SemanticXMLParser.parse(Data,limits:observation:) produces immutable
  ordered logical nodes, with sourceSHA256 and namespace-aware names; strict
  UTF8/XML, DTD prohibition, node/depth/attribute/text limits and cancellation.
- Existing SemanticID.section/block, SemanticRevision, SemanticLogicalAnchor and
  SemanticBlockRole supply the immutable identity/child-slot contract.
- Existing EPUBSemanticResourceReader owns a bounded original archive snapshot;
  EPUBSemanticPackageLoader supplies validated ordered manifest/spine entries.
- Reject HTML repair, WebKit innerText, regex extraction, random/text-only IDs,
  whitespace normalization without a map, inferred CSS visibility and recursive
  flattening of opaque tables/SVG/MathML as if semantically understood.

## Exact interface and write set

New files under `vreader/Services/Semantic/XHTML/` (each <300 lines):

| File | Interface / responsibility |
| --- | --- |
| SemanticXHTMLTypes.swift | immutable Sendable, Equatable section/block/text-run values; no Codable or persisted schema. Section: revision, resource, occurrence, id, blocks. Block: id, role, anchor, parentIndex:Int?, headingLevel:Int?, runs:[SemanticXHTMLTextRun]. Run: text:String, anchor:SemanticLogicalAnchor. Flat blocks in preorder; parentIndex is nearest emitted ancestor block (including paragraph/heading/caption), always earlier. Runs are owned by exactly one block. |
| SemanticXHTMLLimits.swift | init(xml:SemanticXMLLimits = .init(), blocks:Int=4096, runs:Int=16384, outputUTF16:Int=2*1024*1024); validate all numeric fields positive and <=defaults; validates nested XML limits too. Error enum: invalidLimits, inconsistentSource, invalidDocument, blockLimit, runLimit, outputLimit. Existing source/model/XML errors propagate. |
| SemanticXHTMLExtractor.swift | static extract(resource:EPUBSemanticResource, spineOccurrence:Int, limits:SemanticXHTMLLimits = .init(), observation:SemanticXHTMLObservation?=nil) async throws -> SemanticXHTMLSection. Detached worker owns all CPU work, validates inputs before parser, compares raw SHA256 through parsed sourceSHA256, forwards cancellation and withholds cancelled publication. Observation immutable Sendable closures workerStarted, beforeNode(Int), beforePublication, cancellationForwarded (test instrumentation, no substitute parser/data). |
| SemanticXHTMLWalker.swift | internal worker-local builder traverses only parser-produced tree, bounded depth <=96; classifies blocks, checks budgets before append, emits literal text anchors and deterministic IDs. No external tree entry point. |
| SemanticXHTMLPolicy.swift | static namespace/tag classification and ASCII XML-whitespace predicate; constant policy version. |

Tests under `vreaderTests/Services/Semantic/XHTML/`:
`SemanticXHTMLStructureTests.swift`, `SemanticXHTMLSafetyTests.swift`,
`SemanticXHTMLIntegrationTests.swift`, shared `SemanticXHTMLTestSupport.swift`
under same directory. No changes to existing identity/model or XML/source APIs.

Tooling: new `scripts/test-semantic-xhtml-contract.sh` copies exact semantic
source/model files and relevant test helpers to a temporary Swift6 package with
Foundation/CryptoKit/zlib only; original status/full log and per-file SHA256/blob
manifest saved. Actual positive test counts and each of the 3 suite footers are
required (no skip accepted). 300-second exact-process watchdog for Swift run;
one owner/completion channel; temporary workspace cleaned on completion.
New `.github/workflows/semantic-xhtml-contract.yml` runs pinned checkout/upload
on macos-15, contents:read, branch push and PR path filters. Native harness
`scripts/test-native-semantic-foundations.sh` adds a fourth disjoint XHTML lane,
3 exact suite aliases, retaining all existing guards. Exporter
`scripts/export-native-package-evidence.py` adds source files plus the 6 new text
lane members to its bounded allowlist (8MiB total unchanged; full logs artifact).
`.github/workflows/native-reader-check.yml` adds this branch and pins its baseline
to full bfe162c8 SHA; existing 181 branch retains its old baseline. Existing patch
allocator derives 3.67.14/1056 (foundation has no externally visible capability).
XcodeGen-generated project.yml/PBX pair is the final version-only commit; no
handwritten PBX. Local Xcode is now available; own CI remains a fallback and PR
gate. Source-only harness execution is additional to native run-tests.sh gates.

Docs: this plan, docs/features.md, docs/architecture.md,
docs/adaptive-reader/README.md, dev-docs/verification/feature-182-20261007.md,
.claude/codex-audits/plan-feature-182-gate2-audit.md and feature-182-gate4-audit.md.
No Android, existing reader/import/search/backup, UI, schema or dependency edits.

## Frozen extraction policy v1

Require namespace `http://www.w3.org/1999/xhtml`, local-name `html` root with
exactly one direct XHTML body. Missing/multiple body, non-whitespace root text,
or unexpected direct root elements (other than at most one head before body)
reject invalidDocument. Root comments/PI/whitespace allowed. Empty body succeeds.
Head is metadata and deliberately excluded. Namespace/tag comparisons literal,
case-sensitive. No HTML fixups. XML syntax errors never yield partial output.

Walk body descendants in source order; anchor paths start at XML root and count
ALL retained child slots (including whitespace/comments/PI). Comments/PI emit no
semantic content. Semantic containers: blockquote→quote, ul/ol→list, li→listItem,
figure→figure. Emit container block even empty, then children with parent linkage.
Headings h1...h6→heading (level retained), p→paragraph, figcaption→caption:
emit a block then traverse children into it. Known transparent containers
body/div/section/article/main/header/footer/nav/aside and inline
span/a/em/strong/b/i/u/s/small/sub/sup/code/abbr/cite/q/time/mark/bdi/bdo/ruby/rt/rp
traverse without a block. Inline formatting/link targets/language/direction,
ordered-list numbering, image resource references and caption association beyond
parent containment are explicitly deferred. Do not imply these survive as typed
semantics. br/img/hr and ALL unsupported tags or foreign namespaces emit one
opaque block with whole-node anchor, no descendant traversal, no fabricated text.
Thus table/pre/script/style/template/svg/math/iframe/object remain opaque.
No scripts execute; no links/assets/styles are fetched. Hidden/CSS visibility
is not evaluated; literal source text remains source text.

For text nodes: preserve EXACT logical String (no NFC, trim, collapse, synthesized
spaces/newlines, or injected image alt text). Within a current paragraph/heading/
caption or nearest quote/list/listItem/figure, append a source run to that owner.
Outside a semantic owner, non-XML-whitespace text creates an opaque block at that
text node with a text run; whitespace-only text outside an owner is omitted.
Transparent wrappers retain the current owner; nested semantic blocks temporarily
replace it, restoring the outer owner afterward. Therefore parent runs may be
noncontiguous relative to child blocks: consumers use source anchors, and MUST
NOT treat concatenated preorder block texts as a rendered reading stream.
No source text node is copied to more than one run. Mixed content is represented
without double counting. A run anchor points to the text node with range
[0, text.utf16.count); block anchor has nil textRange. Ordinal equals zero-based
block preorder index; no run IDs. Opaque element subtrees are preserved by source
reference, not copied XML or text. Unsupported-only section is nonempty.

IDs depend on revision/resource/occurrence/path/role/ordinal, never mutable layout.
Section revision uses original archive digest and fixed extractorVersion=1. Same
inputs produce same IDs and structure. Different occurrences change IDs. Resource
digest mismatch fails before traversal; malformed digest/path/occurrence rejects.

## Budgets, complexity and cancellation

Hard caps are inclusive and lowerable: XML input4MiB, nodes50000, depth96,
attributes128 per element, aggregate XML UTF16 2Mi, declaration1024 bytes;
semantic blocks4096, text runs16384, total retained output textUTF16 2Mi.
A single run also stays under existing SemanticUTF16Range hard cap. No silent
truncation; overflow throws, with no partial section. All nested XML limits are
validated before parsing; raw Data size checked by parser before scanning/hash.
These are deterministic retained-data/work caps, NOT exact RSS/time guarantees.
Caller already allocated Data; XML and semantic values can coexist. Path overhead
is bounded by nodes*depth and run/block caps. Walk visits at most XML node count,
uses bounded recursive call depth and O(nodes*depth + textUTF16) work. IDs/preimages
are bounded; check cancellation before parse, at each visited node, before and
after publication. Cancel forwarding matches existing XML/package worker pattern.
Per-call mutable state only; concurrent independent calls share nothing.

## WI / TDD / concrete test catalogue

One foundational WI (~450 source / ~400 test lines plus harness/docs). Gate2
must pass before test/placeholder implementation. Commit tests + compiling throw
placeholder, run actual Swift6 RED; then implement GREEN and refactor. Retain
command status/log/source facts for both. Synthetic tiny XHTML/ZIP fixtures are
CI/deterministic boundary exception. User supplies https://book.dosxc.com:9999/opds/ for real EPUB tests. Download
a small sample into gitignored test-books/books/epub, record title/source/digest,
and probe selected chapters through the actual reader/parser/extractor. Record
strict-subset rejection honestly; no book contents committed and no broad corpus
compatibility or VERIFIED claim. Native test fixture remains tiny/CI exception.

- Structure: empty body; headings1–6, paragraph/inline Unicode; nested quote/list/
  item/figure/caption parent relationships; arbitrary wrapper; text before/between/
  after nested blocks, no duplicate node/range; `<p>A<img/>B</p>` image parent
  is paragraph index0, with A/B owned only by paragraph; nested heading/paragraph
  always uses nearest emitted ancestor as parent even if nonconforming XHTML; comment/PI child-slot paths; empty
  blocks; opaque table/svg/math/script/foreign tags, br/img/hr; fallback body text;
  whitespace inside/outside owners, NBSP, CJK, emoji, combining/ZWJ/RTL, CRLF and
  entities/CDATA; namespaces/prefixes; same input stable IDs, changed occurrence.
- Safety: malformed/root/body/head order, DTD/XXE, unknown entity, non-UTF8; every
  semantic cap exact and +1; XML input/node/depth/attribute/text lower limits;
  zero/negative/Int.max config rejects; resource digest/path/occurrence invalid;
  mismatch digest; cancel pre-start, during traversal, immediately before publish;
  deterministic semaphore observation (no sleeps), 16 independent calls.
- Integration: build tiny EPUB using existing EPUBSemanticZIPFixture / EPUBPackageFixture helpers, real
  package loader→spine→real reader→extractor; reopen reader with
  expectedArchiveSHA256: package.archiveSHA256, assert package/resource/section
  archive digests match. Replace archive between package load and pinned reopen
  and require EPUBSemanticSourceError.integrityMismatch (never mixed revision).
  Repeated spine occurrence identity;
  unchanged classic reader (native existing base/package/model lanes); resource
  not selected is not inflated by this one-resource extraction; failure in one
  request does not corrupt a subsequent independent request. Check selected
  raw bytes' SHA256 and resolve every emitted text path against reparsed XML to
  prove full logical text range; explicit no original-byte navigation claim.

## Acceptance / compatibility / risks

Gate2 and Gate4 independent read-only audits, at most3 rounds each, zero open
Critical/High/Medium; all Low dispositioned. Actual compiled behavioral RED then
GREEN; source-only3 suites, native all15 semantic suite guards and distinct
positive executed counts, zero failed/skipped, Debug/Release compile success.
Record exact logs/source/toolchain versions and generated version provenance.
No real-book/UI/production reachability claim; foundational Gate5 tests+audit,
row remains IN PROGRESS through PR, DONE only after merge, never VERIFIED here.
Existing schema/anchors/models/reader behavior unchanged; no migration. Bounded
strict XML rejects some real EPUBs (including DTDs); keep rejection explicit.
Semantic opacity and missing inline/resource metadata are deliberate follow-ups,
not silently claimed complete Phase1. Fork issue mirroring attempted when PLANNED;
if Issues disabled, record exact failure and leave handle absent without changing
repository settings. No invented Refs #182; ID182 is local tracker identity.

## Audit revision history

Round1 FAIL: Medium pinned package/resource reopen missing — fixed with exact
expectedArchiveSHA256 contract plus replacement regression. Low nonexistent
fixture name — fixed to EPUBPackageFixture/EPUBSemanticZIPFixture (both copied).
Low parent ambiguity — fixed nearest emitted ancestor and explicit mixed-content
parent assertions. No rejected findings. Round2 PASS: all three findings resolved; zero open findings of any severity.

Issue mirror attempt2026-10-07: GitHub create_issue returned HTTP410, "Issues has
been disabled in this repository." No settings changed and no GH handle invented.
