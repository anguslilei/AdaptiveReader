---
gate: 4
kind: implementation-audit
feature: 181
rounds: 3
final_verdict: PASS
audited_commit: a2dd1ee7892c263e04a41b218bb66245a65f3dbf
published_commit: 9550a3470d29e481d9fff334815896372d1a26ab
source_tree: 00b31ca85e8a13538aa5630e60a579a7a7ba60e1
---

# Independent semantic identity implementation audit

Independent read-only agent `/root/identity181_implementation_audit`; separate
context from implementation author. No edits, tests, builds, workflows or remote
mutations by auditor. Three rounds exhausted; no inherited feature180 waiver.
Zero open Critical/High/Medium. One Low explicitly accepted under rule47 below.

## Round1 — FAIL

1. **Medium — incomplete version-field uniqueness validation.** Numeric regex
   counted only canonical fields, ignoring additional quoted/commented values.
   A valid YAML override could survive replacement outside the recorded candidate.
   **Disposition:** initially fixed by counting mapping keys before numeric values,
   plus18 quote/comment/flow/escaped-key regressions; round2 found remedy incomplete.

Model confirmations: all nine immutable Sendable Codable/Hashable models below300
lines; constructors/custom decoders enforce bounds; nested resource decoding safe;
literal UTF8 equality/hash and byte slash splitting; exact typed/domain/length/
presence/frozen-role canonical bytes; bounded UInt32 conversion; surrogate boundary
checks;97th child slot rejected before retention; no mutable shared factory state
or production caller. Package/XML assumptions match actual types. Three suites
cover fixed vectors, tuple separation, concurrency, Unicode and decoding.
Native three-lane guards/source evidence coverage and aggregate8Mi ceiling match
the audited plan. No source resolver, CFI or reader reachability claim.

## Round2 — FAIL

1. **Medium — same uniqueness finding partially resolved.** Explicit YAML keys
   (`? MARKETING_VERSION` then `: "9.0.0"`) and anchored keys could still be ignored.
   **Disposition: fixed before round3.** Replaced ad hoc scanning with pinned
   PyYAML6.0.3 BaseLoader parse/compose representation nodes, preserving duplicate
   mapping entries without constructing Python objects. Reject aliases, complex/
   merged keys, multiple/invalid documents and nonmapping roots. Key semantics
   include explicit, anchored, quoted, escaped, tagged and flow forms. Version
   values must canonical single-line plain scalars; raw YAML ceiling2MiB.
   Added regressions including multiline values/literal script content and actual
   CLI evidence/idempotency. Twelve tooling regressions pass locally. Native CI
   installs the exact parser in isolated temporary venvs and exports actual version.

Author measurements: both round2 bypasses were accepted by the prior scanner and
rejected by the new AST implementation. Original quoted-duplicate acceptance was
also reproduced and corrected. These are allocator experiments, **not** XcodeGen
override reproduction. No auditor execution or measured disproval is claimed.

## Round3 — PASS at Critical/High/Medium bar

1. **Low — global replacement may rewrite version-looking literal script lines.**
   Semantic counting correctly ignores a script scalar containing standalone
   `MARKETING_VERSION: 3.67.12` / `CURRENT_PROJECT_VERSION: 1054`, but global textual
   replacement would also change those lines. **Disposition: accepted.** The exact
   pinned baseline54930d4 contains no matching standalone scalar content, and this
   feature introduces no project configuration/script changes. Current allocation
   is therefore unaffected. The actual generated project.yml/PBX pair must be
   inspected and copied byte-for-byte. Before reusing this allocator on a baseline
   with such scalar content, replace only validated YAML scalar spans and add its
   preservation regression. No fourth audit and no unaudited code patch.

Confirmed final parser closes the Medium issue; quoted/explicit/anchored/escaped/
tagged/flow entries are visible; unsupported alias/merge/complex/document/value
forms fail before writes. Numeric bounds, overflow, baseline/candidate acceptance,
pinned SHA and ordinary idempotency remain correct. Wrapper/native exact pinned
parser routes and exported parser version are present; source allowlist facts and
8Mi aggregate ceiling intact. Model sources/tests remain byte-identical to actual
Mac GREEN d749c8a. Earlier model/canonical/concurrency/Unicode confirmations hold.

Accepted restrictions: one bounded project mapping, no aliases/merges/complex
keys, plain canonical version values. No new Apple/runtime/SwiftPM dependency.
Actual native completion, generated tail and docs closeout were pending at audit;
this artifact does not substitute for their subsequent execution evidence.

No findings rejected. No experimental disprovals by auditor. Static negative
model checks confirmed absence of normalization/memberwise bypass/unbounded node
retention/source-precision or production-wiring claims.

Files read across rounds: AGENTS/rules47/40/48/50; plan/Gate2 report; full baseline
diff and both remedial diffs; all nine models/three suites; model/vector/version/
native/export tools plus version regressions; both workflows; checked-in vectors;
project.yml, AnnotationAnchor, actual package/XML types/limits/decoder/builder/
literal-key precedent; watchdog and feature181 tracker subsection.
