# Feature #177 — EPUB semantic source feasibility spike

Status: PLANNED, Gate 2 passed (2 rounds, no open findings). Branch: `feature/177-epub-semantic-source-spike`. Source baseline: `b996ab4d828a180ae4b23d0b07d045b3d318c34f`.

## Problem and purpose

AdaptiveReader needs verified original EPUB bytes and reversible DOM/text source locations before implementing Swift SemanticDocument. Existing EPUBParserProtocol returns decoded String and its shared filename/size/mtime cache does not establish source-byte identity or encoding fidelity. Linux lacks Swift/Xcode; a small executable Python reference spike can establish algorithms and failure behavior now, without claiming a native port is compiled or choosing a Swift dependency blindly.

## Scope / concrete paths

One non-UI feasibility feature; no platform app behavior or persistent schema change. Files:

- `dev-docs/prototypes/epub-semantics/resource_reader.py`: `Limits` frozen dataclass; `SourceResource` raw bytes/digest; `EpubSourceReader(path, expected_sha256, limits, cancelled)` context manager; `read(path)` bounded ZIP entry read; `manifest()` returns verified OPF-relative spine references after bounded XML parse. Never uses the renderer cache. Open one private file descriptor, hash and rewind it; detect file metadata changes before/after reads, and validate optional expected SHA-256.
- `xml_source.py`: `parse_source(data, max_nodes, max_depth, cancelled)` strict, non-network XML parsing with explicit encoding provenance; DOCTYPE/custom entities rejected; `text_runs(element)` original-tree text-node selectors and UTF-16 spans; `resolve_run(root, selector)` verifies every source run. UTF-8 and BOM/declaration-consistent UTF-16 only; unsupported encoding is a typed failure, not Latin-1 fallback. Namespace-preserving all-child-node index paths, no DOM mutation or HTML repair.
- `extractor.py`: `extract_section(resource, spine_occurrence, cancelled)` returns JSON-compatible semantic block roots, nested list/quote structure, heading/paragraph/figure/caption/opaque payloads, original-node selectors, text runs, source digest and deterministic IDs. Identity uses an explicit length-delimited tuple including archive digest/resource path/byte digest/spine occurrence/structural path/kind/version. Preserve inline text and formatting metadata; skip script/style content; unsupported nodes opaque. No random identity, AI, DOM-injected input or real CFI claim.
- `__main__.py`: developer CLI, one selected spine entry at a time; output manifest/section JSON to stdout. No remote downloads or automatic book scanning.
- `tests/test_resources.py`, `test_xml_source.py`, `test_extractor.py`: Python unittest tests; generated tiny ZIP/XHTML fixtures permitted under the CI/exact-structure exception. Tests run locally without pytest/Swift.
- `requirements.txt`: pin lxml to the tested installed version 6.1.1; Python >=3.12. lxml is a development prototype dependency, not a new shipped app dependency.
- `README.md` and `dev-docs/verification/feature-177-20261003.md`: commands, fixture exception, measured results and clear native limitations.
- `.github/workflows/adaptive-foundation.yml`: owner development-branch push + pull_request CI using read-only token; Python reference tests, macOS XcodeGen project-generation and simulator build preparation, immutable versioned artifacts. Never commits from CI, publishes releases, signs code, accesses secrets or uses pull_request_target.
- `docs/features.md`: new row and plan fields. Existing architecture/README gain a developer-tool entry only when prototype lands. Existing foundation documents retain historical baseline evidence; add a continuation/status pointer instead of rewriting past results.

Out of scope: vreader/ and android/ runtime sources, existing EPUBParser/ZIPReader, import/conversion, locators/highlights, AI, embeddings, PDF, adaptive UI, native schema, broad fork-policy changes. Version bump in project.yml + generated pbxproj is required only at PR submission and performed as the final commit after XcodeGen evidence.

## Resource rules

Configurable experimental ceilings: archive 64 MiB, <=4096 entries, compressed entry <=8 MiB, decompressed chapter <=4 MiB, cumulative output <=16 MiB, expansion ratio <=200, <=50,000 XML nodes and depth <=96. Values are explicit test parameters, not production budgets or measured book-compatibility guarantees. Reject duplicate or unsafe paths, backslashes, absolute/drive paths, encrypted/unsupported-compression entries and symlink entries; OPF href resolution permits legal parent-relative paths only while the final archive path stays inside root. Percent-decode once; reject ambiguous encoded separators, NUL and external URI schemes. Check cancellation during hashing/entry streaming/DOM traversal. Enforce actual read output size, declared-size consistency and per-session aggregate limits; advertised-size preflight alone is not evidence of safe decompression. The Python library's underlying zlib decompression buffer remains a prototype limitation to analyze, not a proven Swift bound.

Parser must accept raw bytes, reject unsupported/inconsistent encoding, disable entities/DTD/network/recovery/huge-tree, retain whitespace/comments relevant to source ordering, and check resource/node/depth bounds. No XInclude call. All-child-node selectors are local source-tree paths, not CFIs. Text selectors include node path (counting element, comment and PI children) and text/tail slot; comment/PI content is excluded, their tails remain addressable; source offsets are logical original DOM text-node UTF-16 offsets after XML entity decoding, not raw file byte offsets. No normalized whitespace in this spike: preserving exact text avoids inventing a reversible folding policy.

Block traversal keeps container and child identities while avoiding duplicate flattened prose. Lists/quotes hold child roots; text in unsupported wrappers is opaque. Figures retain original asset href/alt and explicit figcaption binding only. Remote href remains inert metadata; CLI never fetches it. Fixed-layout detection is metadata-only and source reflow is not advertised.

## Sequencing and gates

One PR-sized WI-0: plan → independent Gate 2 → RED tests → minimal reference implementation → GREEN → independent implementation audit → CLI integration/evidence → tail version bump → draft PR. No downstream Swift feature TDD until this feature is merged/DONE and a new numbered plan has passed Gate 2. Main is untouched; user has authorized branch commits and PRs, not automatic merge.

CI bootstrap is docs/config only (TDD exception), may be committed/pushed before prototype so macOS generation can be tested; no PR opens until the final version bump/generated project pair exists. If remote Actions are disabled or XcodeGen unavailable, push reviewed commits and report the concrete blocker; do not hand-edit pbxproj to claim regeneration or silently bypass the per-PR rule.

## Test catalogue and acceptance criteria

- Resources: expected source SHA, changed bytes under same name/size/mtime, duplicate names, path traversal/Unicode href, OPF resolution, encryption/method rejection, ratio/entry/aggregate ceilings, wrong CRC/declared lengths, cancellation, post-close use, FD cleanup, source replacement, empty spine and repeated spine occurrence.
- XML/source mapping: namespaces, UTF-8 BOM/UTF-16, incompatible declaration/BOM, unsupported encoding, DOCTYPE/XXE, malformed XML, depth/nodes, empty chapter, CJK/RTL, numeric entities, combining marks, emoji/ZWJ, text/tail around comments, `<br>` source identity, every run selector resolves to its exact text.
- Extraction: nested wrappers/lists/quotes, headings/inline emphasis/links, figures/explicit captions, duplicate prose with different IDs, repeated extraction equality, revision/version/spine changes, table/MathML/SVG opaque preservation, scripts excluded, no source DOM mutation, cancellation.
- CLI integration: generate one controlled EPUB, run actual CLI, parse JSON and round-trip all source selectors. Benchmark a deterministic large CJK chapter and record bytes/node/time/peak memory as local prototype evidence only. No real test-books are available here; real native/device book validation remains pending.
- Acceptance: all local unittest cases GREEN following recorded RED; independent audits have no open Critical/High/Medium; test/CLI evidence committed; no runtime/persistence/UI change; output explicitly names reference schema/version and precision; all source spans round-trip. No native API, Swift compile, CFI navigation or real-book scalability claim is made.

## Prior art and alternatives

Existing project EPUBParserProtocol/AnnotationAnchor/ZIPReader are source-access/DOM-range precedents, not proven semantic adapters. Official [Python ZIP documentation](https://docs.python.org/3/library/zipfile.html) supports streamed entry access; official [lxml parsing docs](https://lxml.de/parsing.html) expose strict XML and entity/network controls. lxml is libxml2-backed, making a reference XML spike relevant to evaluating a native libxml2 adapter; it does not establish ABI/import/build feasibility on iOS. Swift API/dependency choice remains separate WI-0 evidence on Mac.

Reject regex-strip/HTML-recovery canonical parsing, hidden WKWebView, whole-book eager output and UUID/text-only identity. Reject pretending Python acceptance is Swift acceptance. Reject rewriting existing ZIPReader until bounded native tests demonstrate a need.

## Risks, compatibility and review log

Byte/node ceilings can reject otherwise valid real books and HTML recovery/legacy encodings are intentionally unsupported. ZIP metadata/preflight plus Python stream bounds do not prove exact native decompression-memory limits. FD metadata guards do not provide an immutable snapshot against arbitrary same-inode modification; expected SHA and per-resource digests provide identity evidence, not a synchronization guarantee. Parser cancellation is checked before/after bounded native parse plus during traversal; no claim of interruption inside a C parsing call. No user data migration is needed; reference JSON is experimental and not a shared wire contract.

Gate 2 rounds/dispositions are recorded in `.claude/codex-audits/plan-feature-177-gate2-audit.md`; implementation audit is separate. Status advances to PLANNED only after independent plan review. CI is a capable-lane proposal until its own run succeeds.

## Round 1 corrections (2026-10-03)

- Manifest contract: require container namespace `urn:oasis:names:tc:opendocument:xmlns:container` and OPF namespace `http://www.idpf.org/2007/opf`. Exactly one supported `application/oebps-package+xml` rootfile is accepted; multiple supported rootfiles are an ambiguity error. Require unique nonempty manifest IDs, one manifest and one spine, resolvable idrefs and existing XHTML resources (`application/xhtml+xml`). Reject an empty spine; retain repeated itemrefs with distinct occurrence indices. Reject xml:base anywhere in package/container. Fixed-layout properties are inert metadata. Tests cover each failure and repeated occurrences.
- URI contract: before decoding reject schemes, authorities, protocol-relative references, literal query/fragment delimiters, malformed percent escapes, encoded slash/backslash/query/fragment/NUL, raw backslash and NUL. Decode once as strict UTF-8; reject residual percent escapes (double encoding). Resolve legal parent components relative to the package directory and require containment; absolute paths/drive paths fail. A literal percent filename must use `%25` and must not produce a residual escape. Tests include percent filenames, Unicode, encoded delimiters and parent-relative hrefs.
- Ownership contract: synchronous reader confined to creating thread. Nested/reentrant operations and cross-thread calls fail. Close is idempotent on the owner thread; failed open closes the private descriptor. Any failed resource read closes the whole session, retaining aggregate accounting for emitted decompressed bytes until close. Post-close operations fail. Callback cancellation cannot reenter the reader. Tests verify thread/reentrancy/failed-read cleanup and descriptor closure.
- CLI contract: complete extraction and serialize before writing stdout. Validation/extraction errors exit 2 with useful stderr and no result JSON; invalid/negative spine indices fail. Keyboard interruption exits 130 with empty stdout. Actual subprocess tests cover good output, invalid archive/XML/index and budget rejection.
- Native submission contract: the macOS lane regenerates with XcodeGen and runs `xcodebuild build` for a generic iOS Simulator without signing. A final bumped source revision must have generation/build evidence; generation alone is never recorded as build success. If the capable lane is blocked, document it and keep PR draft/unready (or withhold PR if no regenerated pair), rather than bypassing rule 40.
- WI-0 estimate: approximately 12–18 files and 1,000–1,600 new lines, including tests/documents/workflow. Keep each Python module around 300 lines or less and split package/URI helpers if needed. Foundation audit documents are additional already-reviewed documentation. Record material estimate variance at Gate 4.

## Gate 3–5 outcome

43 unittest methods GREEN after recorded regression RED; controlled CLI runs
round-trip original selectors. Gate4 independent round2 PASS, no open findings.
Native XcodeGen2.46.0 generated the bump, but builds are blocked: Xcode16.4
schema Sendable checks, and Xcode26.3 existing EPUBReaderContainerView expression
type-check timeout. No native runtime source was modified. Submission stays
draft/unready for merge; real-book/device/native integration remains unverified.
