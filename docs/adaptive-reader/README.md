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
