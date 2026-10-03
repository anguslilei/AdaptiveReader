# Phase 1 implementation contract — deterministic EPUB semantics

Status: draft foundation; feature ID not allocated, no tracker status advanced. Before implementation, reserve an ID, expand/move the accepted contract into `dev-docs/plans/YYYYMMDD-feature-N-epub-semantics.md`, update docs/features.md according to its binding rules, and complete independent Gate 2. This document is not permission to skip those gates.

## Problem

The reader's current EPUB search extraction returns flattened text and loses original DOM nodes, inline ranges and figure/caption relationships. We need a format-neutral, deterministic representation for future assistance and layout, with a reversible path to original source. Keep EPUB rendering unchanged while proving that representation.

## Scope

EPUB only; initially an in-memory extraction library alongside the existing renderer. Support headings, paragraphs with inline runs, figures, captions, nested quotes and lists. Preserve unsupported source fragments as opaque-source blocks, rather than erasing tables/formulas or pretending they have been semantically understood. No LLM, embedding, network fetch, UI, auto extraction at app launch, PDF reconstruction, search-index rewrite, data-schema migration or provider changes.

Empty chapters remain represented. Section identity uses spine occurrence + original href. Fixed-layout EPUB is recognized but not admitted to adaptive reflow. Source anchors represent original content; CFI is optional until a valid source-tree/package mapping has been implemented and verified. A fragment-local DOM path must never masquerade as a complete EPUB CFI.

## Proposed files and signatures

Paths are proposed new files; none exist at the audited baseline. Keep each code file near/below 300 lines, splitting case payloads when needed.

| New file | Proposed contract |
| --- | --- |
| `vreader/Models/Semantic/DocumentRevision.swift` | Validated renderFingerprint, optional sourceCanonicalKey, schema/extractor versions and source digest |
| `vreader/Models/Semantic/SemanticID.swift` | Explicit canonical tuple encoding and SHA-256 identity constructor; round-trip Codable validation |
| `vreader/Models/Semantic/SemanticDocument.swift` | Document/manifest and lazy section descriptors with extraction coverage |
| `vreader/Models/Semantic/SemanticSection.swift` | Spine occurrence, resource identity, source order and ordered block roots |
| `vreader/Models/Semantic/SemanticBlock.swift` | Shared block header, typed payloads, nested children and references |
| `vreader/Models/Semantic/SemanticInlineRun.swift` | Text, emphasis, links and original mapped text spans; explicit Unicode/UTF-16 contract |
| `vreader/Models/Semantic/SourceAnchor.swift` | Pure typed EPUB selectors now; format-neutral source identity/precision wrapper; later PDF/text selector implementations |
| `vreader/Models/Semantic/SourceTextMap.swift` | Piecewise normalized semantic range ↔ original text-node ranges; ambiguity/failure is explicit |
| `vreader/Services/Semantic/SemanticSectionExtracting.swift` | `extract(_ input: SemanticSectionInput) async throws -> SectionExtractionResult`; input carries revision, verified original bytes/decoded XHTML, encoding provenance, digest, href and spine occurrence; result carries section/coverage/diagnostics |
| `vreader/Services/Semantic/EPUB/EPUBSemanticResourceReader.swift` | Independent bounded original-archive entry reader, returning verified bytes/encoding/digest; fingerprint-based cache ownership, duplicate-entry rejection and real decompressed-byte ceilings |
| `vreader/Services/Semantic/EPUB/EPUBSemanticDOMParser.swift` | Chosen structural parser adapter, bounded resource policy, recoverability and original-node map |
| `vreader/Services/Semantic/EPUB/EPUBSemanticExtractor.swift` | Deterministic traversal/classification; cannot import SwiftUI/WebKit/AI |
| `vreader/Services/Semantic/EPUB/EPUBSemanticExtractionSession.swift` | Actor owning its semantic resource reader, manifest and one-section-at-a-time extraction; explicit close/cancel lifecycle; existing parser protocol is lifecycle precedent, not canonical byte access |
| `vreaderTests/Models/Semantic/*Tests.swift` | Identity, validation, encoding and source-map invariants |
| `vreaderTests/Services/Semantic/EPUB/*Tests.swift` | Structural extraction, session lifecycle, failures and size budgets |

`SemanticSectionInput` accepts bounded source bytes/decoded XHTML from a verified source resource; parsing recovery and original encoding are recorded in diagnostics. Canonical encodings have explicit byte length boundaries so hrefs containing separators cannot collide. Original bytes/href remain available for navigation even if a separately defined identity field normalizes text.

The current parser API returns only String; its UTF-8/Latin-1 fallback and filename/size/mtime cache cannot satisfy raw-resource verification. WI-0 must choose a bounded archive/decoding adapter before claiming resourceDigest or exact source fidelity. Existing ZIPReader exposes entry metadata and raw extraction, but grows decompression buffers; checking advertised uncompressedSize alone is insufficient. Prove actual output ceilings, cancellation, duplicate archive entry rejection, encoding declaration handling and cache/source revision checks before reuse. The semantic path must not invoke legacy parser.open (which extracts the first chapter) before its resource limits have been enforced. Shared parser APIs and renderer cache/lifecycle remain unchanged.

Files out of scope: reader hosts/dispatch, ReaderAICoordinator, existing AI providers and tools, search extractor/index, SwiftData models/migrations, Android app, backup contracts, and existing position/highlight stores. Build configuration changes may be needed for an explicit parser dependency and Xcode project regeneration; only after the dependency choice is audited and XcodeGen is available. Shared contract files are deferred until the wire format is ready for a conformance lane.

## Prior art and rejected alternatives

- Project precedent: [EPUBParserProtocol](../../vreader/Services/EPUB/EPUBParserProtocol.swift) is async/Sendable; [MockEPUBParser](../../vreaderTests/Services/EPUB/MockEPUBParser.swift) supplies lifecycle/chapter fixtures; [AnnotationAnchor](../../vreader/Models/AnnotationAnchor.swift) preserves DOM ranges and source coordinates. Reuse boundaries, not UI objects.
- [EPUB CFI 1.1](https://idpf.org/epub/linking/cfi/epub-cfi-20170105.html) uses structural package/document paths and UTF-16 text offsets. Preserve CFI when truly available; do not invent a CFI from semantic paragraph numbers.
- [Pretext](https://github.com/chenglou/pretext) is measurement/layout tooling, not an EPUB parser. It has no role in this extraction phase.
- Reject regex-flattened search text as canonical semantic input: DOM/source mapping has already been lost.
- Reject hashing only block text: duplicate paragraphs and captions must have distinct identities.
- Reject fresh random UUIDs for derived block identity: repeated extraction must be deterministic.
- Reject content-dependent AI classification in Phase 1: results and source maps must be testable without credentials/network.
- Reject a hidden WKWebView as the first parser: main-thread/browser lifecycle and injected-DOM differences complicate deterministic worker tests. A real structural parser must prove recoverability and map accuracy before selection.
- Reject eager whole-book arrays as the extraction-session API: large EPUBs need bounded sections, coverage and cancellation.

## Work items

| WI | Scope | Verification / approximate size |
| --- | --- | --- |
| 0 | Parser/source-node and bounded original-resource feasibility spike; compare structural parser choices, decoding, archive limits and original DOM recovery | Separate audited decision; small fixture/prototype files; no production reader changes; gate blocks extraction implementation until byte fidelity and budgets are proven |
| 1 | Domain identity/anchors/runs/maps and canonical encoding | Foundational; RED/GREEN value tests, source-span round trips; ~300–600 lines across small files |
| 2 | XHTML structural extraction for one bounded section | RED/GREEN extraction catalogue, coverage diagnostics and unsafe-input rejection; ~400–800 lines across adapters/tests |
| 3 | Independent semantic source session + lazy manifest/section access | Lifecycle/close/cancel/failure tests through original-byte archive fixtures, no reader-owned parser closure/cache reuse; ~200–400 lines |
| 4 | Integration/benchmark evidence + developer-only extraction entry if needed | Real EPUB sample set on Mac; exact/approximate source outcomes and resource budgets documented; no production UI surface |

Each WI receives the repository's audit/testing gates and a focused PR. Downstream dependent work waits for its prerequisite to be merged/DONE per rule 48. Register the feature's full acceptance criteria before coding; do not mark a code-written slice verified before running its tests.

## Extraction rules to settle in WI-0/1

1. Traverse original body content in source order. Heading level comes from h1…h6. A section wrapper alone is not a paragraph. Maintain hierarchy without multiplying ancestor/descendant text.
2. Preserve semantic inline text and its original per-text-node ranges; decode entities once, retain explicit soft breaks and whitespace policy. Quote and list children remain ordered. Paragraph grouping around inline images is recorded rather than silently discarding text.
3. Figure identity belongs to the original image/figure node. Use only explicit figcaption/structural markup for automatic caption binding in Phase 1; proximity-only guesses are marked unresolved. Resolve resources within the EPUB archive, without external downloads.
4. Remove script/style from semantic content without executing it. Record unsupported table/MathML/SVG/custom structures as opaque source-backed blocks. Preserve alt text and declared direction/language; do not synthesize missing author text.
5. Malformed input reports diagnostics and precision downgrade. If source-node correspondence cannot be proven after repair, exact anchors are withheld. Ambiguous duplicate text is never resolved by picking its first occurrence.
6. Allocate an explicit UTF-16 mapping policy for surrogate pairs, combining sequences and whitespace folding. All range endpoints must be valid; selection display snapping does not change persisted source coordinates silently.
7. Extraction quality can be complete, partial, unsupported or failed per section; document coverage records each section independently. Failed/cancelled work publishes no complete result.

## Test catalogue

Synthetic tiny fixtures are appropriate for CI-unit and exact-structure cases under AGENTS.md's fixture exception; real book/device/performance verification uses available real books first. Local gitignored test-books are not present in this checkout, so that verification remains pending until supplied on the Mac lane.

| Area | Required cases |
| --- | --- |
| Identity | Same source/version gives same IDs; duplicate text different nodes; duplicate href in different spine occurrences; original id duplicates; separators/control chars in tuple; extractor upgrade invalidates IDs; different resource bytes differ |
| Domain validation | Empty metadata/section; invalid digest/version; unsupported decoded versions; invalid offsets, reversed ranges, NaN/infinity in future numeric fields; duplicate IDs rejected |
| Structure | Empty/bodyless chapter; nested section/div; h1–h6; inline strong/em/a/br; quote in list and list in quote; ordered-list start; nested lists; no double text counting |
| Unicode | CJK punctuation/no spaces; mixed English/CJK; emoji surrogate pairs; ZWJ; combining marks/NFD; RTL runs; language/direction inherited; numeric/named entities; NBSP; CRLF |
| Resources | Figure/figcaption; multiple images; inline image; missing/empty alt; missing asset; remote scheme; percent-encoded/Unicode href; parent traversal; duplicate ZIP names; SVG/MathML/table opacity; caption relationship ambiguity; same filename/size/mtime with changed bytes; concurrent file replacement rejected |
| Malformed/security | Unclosed tags; broken namespaces; excessive nesting; external entity/DOCTYPE; entity expansion; pathological chapter/node counts; dishonest ZIP sizes/expansion ratios; actual decompression ceiling; non-UTF-8 declaration or unsupported encoding; source map failure returns reduced precision |
| Mapping | Normalized text ↔ every original node span; whitespace/entity length differences; repeated quotes return ambiguity; excerpt spanning runs; no offsets inferred from progression |
| Lifecycle | Cancel before open/parse/publish; close during await; failure in one chapter; independent reader/extractor sessions; re-open same/different revision; deterministic result order; no stale result installation |
| Scale | Large chapter and many-spine generated fixtures; bounded outstanding sections/cache; cancellation latency measured; no main-thread parsing; benchmark with large real CJK EPUB on target hardware |

## Acceptance criteria and backward compatibility

- Same source revision/extractor version yields byte-stable semantic identity encoding and equivalent structure; quote/layout/font changes in a later renderer do not alter original anchors.
- Required block types are extracted with source ranges; unsupported content remains represented; repaired/ambiguous positions are not marked exact.
- Original source range round-trip is proven for deterministic fixtures. Actual navigation resolution and full CFIs are the next phase unless implemented and tested explicitly in this feature; preserve existing navigation unchanged.
- EPUB sessions load on demand, close deterministically and cancel without complete/stale publication. Budgets must be chosen and measured in WI-0/4 rather than asserted by prose.
- No AI call, network parser fetch, reader UI delta, automatic launch task, database/backup mutation or classic-reader regression is introduced.
- Tests pass through scripts/run-tests.sh on Mac/Xcode; independent audit has no unresolved Critical/High/Medium findings. Foundational pure values need no new UI/device verification; real EPUB extraction requires the tier-appropriate integration evidence before acceptance.
- Update docs/architecture.md when a service/layer actually lands; update this document's status only with the implementation evidence. No existing user model or stored location needs migration; this phase's state is disposable/in-memory.

## Known prerequisites and unresolved decisions

Parser dependency/importability, original-tree fidelity under malformed recovery, package-to-CFI construction, exact input-size budgets, and measured performance ceilings need WI-0 evidence. Mac/Xcode/Swift/XcodeGen are absent here; Android Gradle bootstrap is network-blocked. Do not describe the feature as buildable or tested until a capable lane executes the target suite.

Inherited AGENTS.md requires explicit instruction before committing; all PRs require a final version-bump commit and XcodeGen regeneration. This foundation is prepared as a reviewable worktree and does not bypass those submission requirements or alter upstream automation/authorship defaults.
