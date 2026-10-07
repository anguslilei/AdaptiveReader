# AdaptiveReader engineering foundation

This directory describes the proposed evolution of the fork into an adaptive AI reading system. These documents are planning artifacts; they do not indicate that the capabilities have shipped.

| Document | Purpose |
| --- | --- |
| [00-repository-audit.md](00-repository-audit.md) | Evidence from the inherited source, reuse opportunities, risks, and validation limits |
| [01-target-architecture.md](01-target-architecture.md) | Proposed boundaries, source identities, retrieval policy, concurrency, and rollout |
| [02-semantic-document-plan.md](02-semantic-document-plan.md) | First implementation contract, work items, test catalogue, and acceptance criteria |
| [03-foundation-review.md](03-foundation-review.md) | Independent review findings and dispositions |

Audited baseline: `b996ab4d828a180ae4b23d0b07d045b3d318c34f` (inherited iOS marketing version `3.67.7`, build `1049`). The source and the existing cross-platform identity contracts take precedence over historical README claims.

The first code phase is deterministic EPUB semantic extraction alongside the existing reader. Adaptive rendering, LLM assistance, PDF reconstruction, and Windows support remain later phases. An implementation feature must be registered and pass the repository's six gates before entering TDD; this foundation does not mark a tracker item PLANNED, DONE, or VERIFIED.

The next checkpoint is [feature #177's executable reference prototype](../../dev-docs/prototypes/epub-semantics/README.md)
and [verification evidence](../../dev-docs/verification/feature-177-20261003.md).
It tests byte/source mapping algorithms without delivering the native adapter.
Original audit/build results above remain historical baseline evidence.


Continuation2026-10-03: PR #2→#1 merged to main95b5ec0, delivering the reference
spike and reader compiler fixes. Feature178 adds the independent Swift byte-reader
foundation under Services/Semantic/EPUB; its33 native Mac contracts and126 iOS tests pass,
with Debug/Release builds at4264fee. See [evidence](../../dev-docs/verification/feature-178-20261003.md). The proposed SemanticDocument/DOM/source-map pipeline
is still a later phase, with no renderer or AI entry point introduced here.

Feature179 next WI: independent bounded native XML logical-tree utility. Mac29
contracts and155 iOS tests pass atd0c16a0 with Debug/Release builds; Gate2 PASS3 and Gate4 PASS2.
It retains source structure without claiming OPF/spine, browser DOM/source-map
or CFI compatibility. See [plan](../../dev-docs/plans/20261003-feature-179-bounded-semantic-xml.md).

See [verification evidence](../../dev-docs/verification/feature-179-20261003.md).

Feature180 implements the native package/spine foundation by composing the real
byte reader and XML utility. A non-inflating resource catalog, strict local URL
resolution and immutable archive/container/OPF identities preserve ordered manifest
and spine occurrences. Repeated idrefs intentionally retain nonconforming input;
this is a bounded subset, not an EPUB conformance claim.

Mac30 contracts pass. Native run37160519963 passes 155 base +30 package
distinct tests in two sequential completed bundles; all nine semantic suites pass,
zero failures/skips, Debug/Release builds pass. Gate2 PASS2 and Gate4 PASS3, zero
open findings. See [plan](../../dev-docs/plans/20261003-feature-180-native-epub-package.md)
and [evidence](../../dev-docs/verification/feature-180-20261004.md).

PR3/4 merged at user confirmation2026-10-03; foundations178/179 are DONE.
Feature180 remains IN PROGRESS pending its PR merge. No production reader/import,
chapter extraction, SemanticDocument/source-map/CFI, renderer or AI entry point is
introduced. Chapter semantic extraction is the next implementation boundary;
real-book compatibility and user-visible adaptive reading remain later verification.


Post-audit correction: native run37160519963 passed both compilers and155+30
real tests, but its exporter failed an unmatched Python parenthesis. A single
trailing parenthesis was removed and verified in own recovery CI at
1f97fa8daed2bfd27be56fa4bc04a210877bb667 (run37162305962). No application/test changes. Gate4 PASS3
is historical atfda86fbb; no fourth audit was run. Rule47's three-round ceiling
requires escalation, so the PR is a draft with this post-audit correction pending
explicit acceptance before merge. Evidence is partial; no VERIFIED claim.


## User acceptance and final native proof2026-10-05

User confirmation2026-10-05T11:07:49+08:00: “好的 确认 然后继续推进开发”.
This explicitly accepts the post-round3 one-character exporter correction and
continues the previously described PR5 closeout/dependent development. It does
not claim a fourth independent audit. Gate2 PASS2 and historical Gate4 PASS3
remain; the exact one-character exception is accepted by the user.

Final PR input ab60ac6bf4184b4e4c9b1af880411172aaed4c9b:
all five pull_request workflows completed successfully, including native run
37177554340 (Debug/Release, two real lanes and corrected evidence exporter),
source37177554363, XML37177554309, package37177554297 and foundation37177554310.
The earlier cancelled push-native run was superseded by this successful PR run,
not counted as a pass. Foundational acceptance is complete; no production
entry point, real-book compatibility or VERIFIED/release/tag claim.

Closeout also restores the complete pre-PR architecture document verbatim from
main55719b27c62c0f0d37556618d4525a0ea8e1135e and retains the added package section.
The prior closeout accidentally prefixed the addition with “undefined” and omitted
the inherited document. This documentation-only recovery is not covered by the
exporter exception and needs no additional code audit under the docs-only scope.

Final closeout checkpoint: PR5 subsequently passed all five workflows at
review head236c0145a7aec775505bdcda5b53c4a8f1609302 and merged as
54930d465d57cdce5699f36cf9edd14b222e3655. Native run37258668628 executed
Debug/Release and155 base +30 package distinct passing tests, all nine suite guards,
zero failed/skipped; artifact11324671453 ZIP digest0466173f1248aed9ef64d6a14706fe8224ece18c26f0f522929e3bd277f0377a
was recomputed and all24 manifest members verified. The earlier pending paragraphs
above are historical checkpoints; feature180 is now DONE, enabling feature181.

## Native semantic identity foundation — feature181

Nine dormant immutable Swift values add exact archive/resource revisions, literal
UTF8 archive filenames, bounded logical XML child-slot paths, UTF16 ranges and
source-bound deterministic SHA256 IDs. Canonical bytes include domain/kind, raw
digests, version numbers, length-prefixed paths, spine occurrence, child slots,
optional range presence, frozen role tag and ordinal. Layout/reader goal/text alone
cannot determine identity. Validated decoders enforce the same constructor rules.

Logical anchors represent syntax; they do not resolve source nodes or promise
exact original-reader positioning, browser DOM, XPath or CFI. Models are dormant:
no chapter extraction, UI, renderer, AI, session or persistence integration.
The next native slice is bounded XHTML-to-semantic-block extraction using these
values, followed by source mapping/resolution and production integration.

[Plan](../../dev-docs/plans/20261005-feature-181-native-semantic-identities.md),
[Gate4 audit](../../.claude/codex-audits/feature-181-gate4-audit.md): three rounds,
zero open Critical/High/Medium, one explicit accepted Low in CI version tooling.
Actual source-only Mac GREEN32/3 and ten independent vectors pass. Native
Debug/Release and217 distinct tests pass (155 base +30 package +32 model),
zero failed/skipped and all12 semantic suites. See [evidence](../../dev-docs/verification/feature-181-20261005.md).
Actual generated version pair3.67.13/build1055 is retained for the final PR tail.


PR6 merge acceptance2026-10-07: review head8d1f063 passed all three PR workflows
(model37615459526, foundation37615459536, native37615459582). Native Debug/Release
and217 distinct tests passed, zero failed/skipped, all12 semantic suite guards.
The verified generated3.67.13/build1055 pair is unchanged. Feature181 reaches DONE
with the merge; its models remain dormant and no production/VERIFIED claim is made.
Single-section bounded XHTML semantic extraction is the next dependent boundary.

## Single-resource XHTML extraction — feature182

The next foundational slice adds a bounded strict-XHTML extractor over the native
resource/XML/identity utilities. Semantic blocks retain logical source anchors,
unsupported subtrees stay opaque, and text runs preserve parser text without
normalization. Limits and cancellation reject the whole result on failure.
The API consumes one resource; archive sessions, production reader integration,
inline metadata, source resolution/normalization maps and CFI remain follow-ups.

[Plan](../../dev-docs/plans/20261007-feature-182-bounded-xhtml-semantics.md) passed
independent Gate2 in two rounds. Local Swift6 actual behavioral RED was followed
by GREEN21 tests/3 suites. Native238 distinct tests and Debug/Release builds pass;
Gate4 PASS1 has zero findings. Five original real CJK resources pass extraction
and logical text-anchor validation. Full native archive compatibility is limited
by compressed directory entries and DTD rejection in the sampled corpus; see
[evidence](../../dev-docs/verification/feature-182-20261007.md). This is not a
production/VERIFIED claim. User-supplied TaleBook OPDS EPUBs are local-only
integration inputs; no book content is committed.
