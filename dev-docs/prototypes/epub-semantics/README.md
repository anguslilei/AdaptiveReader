# EPUB semantic source reference prototype (feature #177)

Developer feasibility tooling, Python 3.12+, **not integrated into either app**.
The [formal plan](../../plans/20261003-feature-177-epub-semantic-source-spike.md)
and [audit](../../../.claude/codex-audits/plan-feature-177-gate2-audit.md) define
its accepted subset and prerequisites for a native successor.

```bash
python3 -m pip install -r dev-docs/prototypes/epub-semantics/requirements.txt
python3 -m unittest discover -s dev-docs/prototypes/epub-semantics/tests -v
python3 dev-docs/prototypes/epub-semantics/__main__.py YOUR.epub --spine 0
```

`--expected-sha256` checks archive identity. `--resource-limit` overrides the
experimental resource ceiling. JSON is written only after complete extraction;
validation errors write a diagnostic to stderr and exit 2 with empty stdout.
Interruption exits 130. Selected spine indices are zero based.

The reader owns a private descriptor and never calls EPUBParser.open or its
renderer cache. It is synchronous, thread confined and nonreentrant. Use a
context manager or explicitly close it; close is idempotent, failed operations
close the session. Bytes emitted by rejected reads still consume that session's
budget. All entries are preflighted; unused oversized assets can reject a book.

Supported package: one supported container rootfile, OPF namespaces, nonempty
XHTML spine, unique manifest IDs and resolvable existing local resources.
Repeated spine references remain separate occurrences. Local URI subset rejects
schemes, authorities, queries/fragments, ambiguous/double percent encoding,
encoded delimiters, backslashes, xml:base and paths escaping archive root.

Only strict UTF-8 (optional BOM) and BOM UTF-16 with consistent declarations are
accepted. No Latin-1 fallback, HTML repair, DTD/entity loading, network or XInclude.
Source selectors count **all children**, including comments/PIs. Text/tail runs
preserve whitespace and use logical decoded DOM text-node UTF-16 offsets. Comment
and PI contents, script/style prose are excluded; their following tails remain.
Selectors are local original-tree paths, **not CFIs or renderer DOM coordinates**.

Blocks preserve container/list/quote structure, explicit figure captions and
inline formatting/source paths. Unknown structures retain an opaque original
subtree selector, attributes and text runs; no active markup is emitted. Raw
resource bytes must be retained by a future adapter to resolve opaque subtrees.
Deterministic SHA IDs encode archive/resource digest, path, spine occurrence,
selector, kind and extractor version; no text deduplication or random IDs.

Experimental ceilings: 64 MiB archive, 4096 entries, 8 MiB compressed resource,
4 MiB output/resource, 16 MiB cumulative output, ratio 200, 50k XML nodes/depth 96.
STORE/DEFLATE only; duplicate/unsafe/symlink/encrypted entries rejected. A bounded
raw-deflate loop verifies complete stream, output length and CRC independently
of advertised output length (ZipFile alone can accept a forged prefix).

Limits bound this reference input/output, not proven native app peak memory.
XML parse cancellation is before/after the bounded C call and during traversal;
it cannot interrupt inside libxml2. Node/depth counts are verified after parse.
Stat guards detect common replacement/modification, but cannot establish an
immutable snapshot against arbitrary same-inode mutation. No real-book/native
compatibility, CFI navigation, fixed-layout reflow or performance claim is made.
Synthetic fixtures use the repository's CI/exact-structure test exception.

[Verification evidence](../../verification/feature-177-20261003.md) records
RED/GREEN, CLI integration, synthetic measurements and native CI blockers.
