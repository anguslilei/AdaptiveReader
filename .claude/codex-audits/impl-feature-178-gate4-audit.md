---
gate: 4
kind: implementation
feature: 178
plan: dev-docs/plans/20261003-feature-178-native-epub-source-reader.md
rounds: 1
final_verdict: REQUEST_CHANGES
---

Independent read-only feature177_plan_audit context; no edits/builds/network.
Round1: five Medium findings, zero Critical/High. Fixes applied by author;
round2 rereview pending. No source approval/execution is inferred.

| Finding | Severity | Applied correction |
|---|---|---|
| R1-1 fileURL NUL truncation at CString | Medium | Reject NUL before open; existing valid prefix fixture |
| R1-2 post-close fd assertion races with reuse | Medium | Observe actual deferred close status once for same fd |
| R1-3 overlap fixture fails name matching first | Medium | Valid inner LFH embedded in outer payload; only overlap guard rejects |
| R1-4 aggregate CI counts can omit new suites | Medium | Passed xcresult nodes required for all3 new suite names, zero skips |
| R1-5 factory cancellation not exercised after worker start | Medium | Bounded deterministic worker/start/publication gates; actual child cancellation, close/no publication assertions; source mutation during read |

Auditor confirmed reachable byte arithmetic bounds, central/local metadata and
descriptor comparisons, pre-CD nonoverlap spans, raw stream end/input/length/CRC,
actual budgets, nonreentrant actor ownership and failure closure, snapshot identity,
safe nonregular open and existing worker cancellation checks. Tests/harness use
exact production sources. Mac29 contracts GREEN at8e4f56e before refinements;
updated Mac/iOS evidence remains pending.
No rejected remedies or measurement-disproven findings.
