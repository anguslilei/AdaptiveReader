---
gate: 4
kind: implementation
feature: 178
plan: dev-docs/plans/20261003-feature-178-native-epub-source-reader.md
rounds: 3
final_verdict: PASS
---

Independent read-only feature177_plan_audit context; no edits/builds/network.
Round1: five Medium findings, zero Critical/High. Fixes applied by author;
round2 PASS, zero open findings. Source approval does not imply native execution.

| Finding | Severity | Round2 disposition |
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
updated Mac32 evidence is recorded below; iOS evidence is recorded separately.
No rejected remedies or measurement-disproven findings.

## Round2 PASS

All five findings closed after independent rereview. The test probe's mutable
state is lock protected; waits are bounded; observation defaults preserve actual
IO/actor ownership. ZIP/inflate bounds and previously confirmed actor invariants
remain intact. No new findings, no rejected remedies or measurement dismissals.
Own updated Mac run37105061416 at7e19006 compiles exact Swift6 production sources
and32 tests in3 suites pass; this is author-run execution evidence, not auditor
execution. iOS outcome will be recorded separately in verification evidence.

## Round3 PASS — platform path correction

Independent read-only rereview of source4264feed0b360c5d2423ea227fc5ff3fa999c280:
zero Critical/High/Medium/Low findings. All five round1 findings remain closed.
The encoded URL path is decoded exactly once; the same validated string reaches
POSIX open. Both NUL URL constructions are rejected, while space/CJK/literal
`%00` filenames have an actual-file regression test. Descriptor close observation,
valid overlap fixture, bounded factory cancellation and no-publication guarantees
remain intact. CI retains the test exit status and full raw log, harvests results
even on failure, requires completed Info.plist bundles and passed nodes for all
three new suites with zero failures/skips. No compiler stage or test guard is
skipped. No new findings or rejected remedies. This is static review, with no
auditor execution; author-run Mac33/iOS126 evidence is recorded separately.
