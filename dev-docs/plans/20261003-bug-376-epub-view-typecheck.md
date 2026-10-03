# Bug #376: reader container expressions fail native compilation

Branch `fix/376-epub-view-typecheck`, stacked on feature177 at
`328ff01bf4d336fdd9961e7bd10ab9f7d2bae803`. No dependency on the prototype's
algorithm; this branch reuses its capable CI bootstrap. PR will target the
feature branch, not merge main automatically.

## Understand / RED

Own pipeline run37089271133 at that SHA uses Xcode26.3 / 17C529 and
XcodeGen2.46.0. `xcodebuild build -project vreader.xcodeproj -scheme vreader
-destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`
fails EPUBReaderContainerView.swift:143:25 with expression type-check timeout.
This is the actual compiler regression check; a source-text assertion or Swift
unit test that cannot compile would not provide stronger reproduction.

The body contains ~370 lines with one ZStack plus asynchronous lifecycle,
navigation notifications, annotations/sheets, theme/layout changes and bilingual
modifiers. Existing comments already identify type-inference complexity as a
reason for dedicated modifiers. The precise trigger is not asserted without
compiler evidence; decomposing into opaque view expressions is the tested remedy.

## Minimal change

Split the EPUB expression into four private `some View` computed properties plus body
within the same struct/file: base lifecycle, navigation, annotations,
appearance/layout and final bilingual/debug body. Keep the same modifier order,
closures, State storage, access controls, DEBUG conditionals and accessibility
scoping. Do not add AnyView, new containers, Tasks, event routing, actor isolation,
UI design, settings behavior or persistence changes. No public API change.
The legacy file exceeds 300 lines; this limited fix does not attempt unrelated
state/bridge file migration. New tooling/doc files remain small.

CI changes select explicit 3.67.9 (1051) candidate generation in this fix branch,
record xcode/generator/commit provenance, compare Debug and Release compilation,
and run existing related tests via scripts/run-tests.sh on a booted simulator.
No credentials/secrets/signing/releases or CI pushes. Final bump is copied from
verified generator artifact and committed last before draft PR.

## Verify / acceptance

- Baseline RED captured from actual Xcode compiler; same app build becomes GREEN.
- Debug and Release build to catch conditional-modifier compilation.
- Existing EPUB reader VM, chapter navigation/wrap, host lifecycle and bilingual
orchestration tests through the repo wrapper; discover supported simulator first.
Record inability to run any lane as a confirmed blocker, never a successful test.
- Independent read-only implementation audit: compare modifier/closure order,
state ownership, access controls and conditional branches; no open C/H/M findings.
- Record evidence at dev-docs/verification/bug-376-20261003.md, tracker stays
IN PROGRESS until merged under AGENTS' stronger closure gate. GH mirror remains
blocked by disabled Issues (prior 410).

Repository command names `/cc-suite:bug-analyze` and `/cc-suite:audit-fix` have no
installed callable command or matching local entry. Equivalent source analysis,
own CI reproduction and separate read-only audit are used explicitly; no claim
of invoking unavailable commands. User has already authorized branch commits/PRs.

## Plan review correction

Independent review round1: Medium selected-Xcode override in run-tests.sh and
Low ambiguous stage count. Both addressed: preserve caller DEVELOPER_DIR with
existing fallback; regression shell test stubs xcodebuild and verifies selected,
unset and empty environment cases before/after fix. Record selected compiler
in each CI lane. Five expressions mean four private properties (`lifecycleReader`,
`navigableReader`, `annotatedReader`, `appearanceReader`) plus existing `body`.
Boundaries: ZStack→scenePhase; bookmark→DEBUG navigation; import→unified popover;
photo→layout observer; final body bilingual/settings/debug modifiers.

## Candidate compiler result / scope correction

Own run37090216334 at740dfab9e2ac16027363614255329c178cc342c1 compiles the
originally failing EPUB view, then fails the same type-check timeout in the
unchanged upper dispatcher ReaderContainerView.swift:268. Debug fails there,
so Release/tests do not run. Bug scope now includes both existing reader
container expressions; no algorithm/product behavior is added.

ReaderContainerView's body is ~775 lines. Add eight private opaque properties
plus body, keeping nine contiguous regions: original content ZStack; chrome
observers/style; AI sheets; selection/dictionary/AI handlers; bilingual/provider/
TOC/position/retranslate observers; the complete DEBUG observer block; deferred
setup + settings/annotations/search/share sheets; book-details/mirror/banner;
existing body with search setup and task/probe disappearance/DEBUG registration.
Every closure, order and conditional remains verbatim. No extra containers or
state extraction. Independent scope review and final implementation comparison
must cover both views. Baseline compiler evidence now includes the second run.

## Candidate verification outcome

Own run37090899757 at07c27cdcf1032b473ddf8eedd41bbfdbfc3a34ae passes Debug,
Release and 93 related native tests (zero failures/skips), with Xcode26.3 /17C529
and iPhone17Pro /iOS26.2. Independent expanded plan and implementation audits
PASS after3 rounds. The candidate's actual XcodeGen2.46.0 version pair3.67.9
(1051) is copied into the final version-only commit. Evidence and precise scope
are in dev-docs/verification/bug-376-20261003.md. Draft submission is separate
from the merge gate; the tracker remains IN PROGRESS until merged.
