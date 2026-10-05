---
gate: 2
kind: plan-audit
feature: 180
plan: dev-docs/plans/20261003-feature-180-native-epub-package.md
rounds: 2
final_verdict: PASS
---

Independent read-only xml179_audit context; author root. No edits, tests, builds,
network or delegation by auditor. Plan only; no Gate3 or runtime success claim.
Baseline b0c0a2494947c1df00a178f0df91a77ae916d5e7; both prerequisites unmerged.

| Round/source | Finding | Severity | Disposition |
|---|---|---|---|
| R1 | Terminal decoded dot/dotdot could collapse directory intent into an existing ZIP file | Medium | Reject terminal dot/dotdot before normalization; raw/encoded and matching-file collision fixtures |
| R1 | Encoded-colon ban ambiguous; inner archive components could bypass it | Low | Ban raw and decoded colon; %3A/%3a fixtures |
| Author primary-source correction during R1 | Rootfile full-path wrongly treated as literal path; R1 auditor initially confirmed this | Medium (author-assessed model correction) | W3C REC2026-01-13 sec4.2.6.3.1.3 establishes URL semantics; decode once from archive root, never META-INF; decoded OPF base stays literal |
| Author scope correction during R1 | Repeated idrefs accepted by existing source-fidelity policy conflict with EPUB3.3 conformance | Low (scope clarity) | Explicit intentional nonconforming-input preservation; no EPUB conformance assertion, no silent deduplication |
| R1 optional refinement | Opaque property-token duplicate identity unspecified | Low (optional) | Use literal UTF8 identity; canonical-distinct tokens stay distinct |
| R2 | All remedies/primary-source corrections rereviewed | — | PASS; zero open findings |

Confirmed actual source reader/XML signatures, resource/tree fields, idempotent
close, lowerable limits, existing observation seam, no catalog API and no production
callers. XcodeGen auto-discovery/Swift6 configuration and native nine-suite extension
are supported by existing tooling. Actor catalog can expose safe immutable file
paths/digest without inflation or cumulative extraction charges. Literal lookup
prevents canonical-equivalent filename/ID substitution. Digest comparisons,
forwarded worker cancellation, actual stage checks and explicit awaited close on
every post-open exit define a coherent lifecycle. DTO/catalog/source/XML budgets
stay independent and finite. One foundational WI is cohesive; repeated occurrences
and linear=false retention are deliberate.

The initial literal-rootfile confirmation is expressly withdrawn: author-supplied
primary W3C text disproved that model. This is a standards/source correction, not
a runtime measurement. R2 confirms corrected decode-once root-relative semantics
and safe terminal-directory/colon rules. Repeated idref tolerance is retained with
an explicit nonconformance qualification; no audit remedy rejected. Optional
literal property identity accepted. Observation signatures/checkpoints and awaited
cleanup resolve implementation ambiguity.

Gate3 remains blocked by rule48 until feature178 and179 are merged/DONE. Reconcile
onto merged main first; repeat plan audit if prerequisite interfaces/contracts
change. No native tests, version bump, delivered package code or UI is claimed.
