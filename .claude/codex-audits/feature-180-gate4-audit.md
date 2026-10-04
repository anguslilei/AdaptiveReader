---
gate: 4
kind: implementation-audit
feature: 180
plan: dev-docs/plans/20261003-feature-180-native-epub-package.md
rounds: 3
final_verdict: ESCALATED
audited_verdict: PASS
reviewed_commit: fda86fbb6f90500ce9449bb5c0d5bd302da10b0a
post_audit_status: awaiting-explicit-acceptance
---

Author root; independent read-only package180_implementation_audit context.
Auditor did not edit, run builds/tests, mutate GitHub or delegate. Source for
round1:6682923be19d37158a0057826ba05ae9a21e491d, against mergedmain55719b2.
Local docs/evidence drafts were excluded from source review. Mac28 tests pass;
iOS/compiler result pending at review time, not independently executed by auditor.

| Round | Finding | Severity | Disposition |
|---|---|---|---|
| R1 | XMLAccess.properties uses maxSplits; at property cap repeated trailing whitespace can become an extra part and reject a valid list | Medium | Native RED measured4 metadataLimit failures (manifest/spine cap1/cap64 with trailing CRLF/whitespace); replaced with cancellable scalar token scan, cap checked at actual new token, actual retained scalars charged before token growth; Resolved; R2 PASS |
| R1 | Synthesized DTO String equality can equate canonically equivalent but literally distinct ID/path/property spellings | Low | Native RED measured2 equality issues; literal manifest/spine/package equality implemented, derived parts equality inherits literal nested identity; Resolved; R2 PASS |

Round1 verdict FAIL, one Medium open. Maximum3 rounds applies. No remedy rejected.

Confirmed actual source/XML signatures and DTO fields, Swift6/XcodeGen discovery,
and absence of production import/reader/renderer/AI/persistence/UI wiring. Catalog
exposes immutable sorted file paths/digest without inflation or aggregate read
charges. Literal keys guard IDs/properties/membership; resource membership and
post-read digest/path checks prevent canonical filename substitution.

Decode-once URLs, already-decoded OPF base, encoded delimiter/colon/control bans,
terminal directory intent and ASCII slash segmentation independent of graphemes
match the scope. Immediate wrappers/namespaces, unqualified attributes, fallback
rejection, media restrictions, repeat/auxiliary spine retention confirmed. Source,
XML, DTO and catalog budgets are independent/lowerable; repeated property field
occurrences charged, catalog payload checked before lookup allocation. Property
token cap edge is the enumerated exception requiring correction.

Every post-open loader exit awaits actual reader closure. Cancellation forwards
through worker/real subsystems and publication follows closure. Observation gates
only coordinate actual work/capture the actual actor, not substitute results.
Fixtures use real ZIP/XML; valid nested-wrapper negatives complement malformed
XML fixtures. Changed Swift files below300 lines, no consequential unrelated
source behavior changes/dead code. Mac harness copies actual sources/strictSwift6,
propagates errors and requires3 package suites; native workflow retains9 semantic
suite/count guards and Debug/Release steps.

Qualified/disproven assumptions: rootfile full-path is a URL, not an undecoded
literal name; repeated idrefs tolerate nonconforming input, not EPUB conformance.
Upstream String-key ZIP index still rejects canonically equivalent distinct ZIP
names; this WI prevents substitution without expanding upstream acceptance.
Package success checks asset existence, not asset CRC/content or real-book
compatibility. Supplied runtime facts are author evidence, not auditor execution.

Author measurement: REDbd5e8569e9d559f601eee7e1d8cdf010fa0a49ae
run37157701843/job111304462771 compiled15.36s then30tests3suites failed6issues,
including all4 cap/manifest/spine combinations and both value equality assertions.
This confirms, rather than disproves, both static findings. Isolated own test
branch avoided disturbing the then-running implementation pipeline; it introduced
no production or input data substitutes. Source fix40af655 implements both
remedies; runtime GREEN/rereview pending. No claimed final PASS.

## Round2 PASS

Independent rereview source40af65502ff0fa5109e254785394b3a0d69b6568 passes with
zero open Critical/High/Medium/Low. Scalar tokenizer skips complete whitespace
runs and checks the limit at actual additional-token start; empty/whitespace-only
values, duplicate/control rejection and independent repeated-field budgets remain
intact. Cancellation checked each scalar; UTF16 charged before output growth,
including supplementary scalars. Literal array/value equality covers every retained
string, nested parts inherit it, numeric/Boolean fields remain included.

Mac run37157905100/job111305069763 compiled19.30s then30tests/3suites passed
0.079s. Audit regards those as author-supplied measurements, not its own execution.
No regressions/additional findings, unrelated change or prod entry point. Earlier
confirmed source/URL/namespace/order/budget/lifecycle/harness assumptions still
hold. All package Swift files below300 lines. Round1 findings fully enumerated
and both confirmed by actual RED then resolved; no remedy rejected. Gate5/native
iOS run37157905091 still pending when R2 passed; Gate4 does not assert merge
readiness, device verification or release success.

## Final round3 PASS — operational harness correction

Subject fda86fbb6f90500ce9449bb5c0d5bd302da10b0a. Independent GitHub read-only
review at this exact ref because local workspace disconnected (409
environment_offline). Comparison confirms exactly three harness/workflow files
changed from R2; app/source/tests unchanged. R1 Medium/Low remain resolved.

| Round | Finding | Severity | Disposition |
|---|---|---|---|
| R3 | Sequential lane ownership, actual result guards and bounded evidence export reviewed | — | PASS; zero open findings |

Original native run37157905091/job111305141100 compiled Debug and Release, then
Swift154 tests18suites failed2 observer-start assertions (.worker package and
.open source budget), after5.768s. Cooperative-pool competition is an inference,
not a proven production defect; no rejection of those tests or relaxed deadlines.

Unchanged legacy reader/EPUB/XML suites run first, unchanged package suites next,
through the original watchdog wrapper on the same pinned UDID. Each invocation
owns original status/start/wrapper/full log/completed bundle/summary/tree.
Successful validation precedes subsequent startup; filters are disjoint and
completed bundle paths must differ. Every lane requires original status0,
successful wrapper/positive full-log execution, typed positive all-passed
counts/failed0/skipped0, expected device and explicit Passed Test Suite nodes.
No merged or fabricated result JSON. Failed commands/validation stop before
subsequent work/final success statement.

Exporter uses a fixed non-secret preparation-file allowlist and scoped source
files; records byte counts/SHA256/Gitblob hashes and missing members. It emits
numbered base64 chunks, exact commit and completion sentinel; decoded export
ceiling8MiB (base64 naturally larger). Full compiler/test logs remain in own
CI artifact with hashes. Git subprocesses only read revision/hash data. No
arbitrary path parameter, secrets access/external execution/write credential.
Sentinel denotes export completion, not test success. Pinned actions, readonly
contents, disabled persisted checkout credentials, Debug/Release and artifact
retention preserved.

Round3 audit does not independently execute tests or establish that sequential
lanes cure the prior timeouts. New native run pending at review; no Gate5,
generated/version-pair or final-native success claim until author collects it.
No remedies rejected; all3 round findings and measurements enumerated.


## Post-audit runtime discovery — escalated, no fourth round

Native run37160519963/job111312824769 passed Debug/Release and the original two
native lanes (155+30 distinct tests, all nine suites Passed, zero failed/skipped).
The exporter then failed Python line27 with unmatched ')'. Round3 static review
missed this operational syntax error. Author removed exactly one trailing right
parenthesis from source_paths sorted(set(...)); no functional source/test changes.

Recovery source1f97fa8daed2bfd27be56fa4bc04a210877bb667,
run37162305962/job111318084266 passed py_compile, exact own native provenance
checks, saved original statuses/counts/full-log/bundle guards and evidence export.
Selected raw bytes were independently SHA256/byte/Gitblob verified; source hashes
confirm all16 previously recorded functional/Mac-harness files unchanged. Recovery
workflow exists only on the isolated evidence branch and is not in the feature PR.

The one-character fix is not independently rereviewed. Rule47 maximum3 rounds
has been reached; no fourth round or relabelled round3 recheck was performed.
Historical R3 PASS remains attached to fda86fbb. Final status is ESCALATED for
explicit acceptance of this narrow post-audit correction; PR remains draft and
cannot be represented as merge-ready. No unresolved functional defect identified,
but the current-source audit acceptance boundary remains pending.
