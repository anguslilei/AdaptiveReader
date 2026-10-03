# Independent foundation review and validation

Date: 2026-10-03 (Asia/Shanghai). Source baseline: `b996ab4d828a180ae4b23d0b07d045b3d318c34f`. Local branch: `docs/adaptive-reader-foundation`.

## Scope and independence

The foundation author prepared the repository audit, target architecture and draft SemanticDocument implementation contract. A separate read-only auditor context (`foundation_audit`) reviewed those documents and their cited repository sources. The auditor made no edits, ran no builds or native test suites, and performed no network operations. The author applies and validates corrections. This satisfies author/reviewer separation for these foundation documents; it is **not** a formal feature Gate 2 pass, implementation audit, build certification or device verification.

## Round 1 findings

| ID | Severity | Finding and evidence | Disposition |
| --- | --- | --- | --- |
| F1 | Medium | The proposed original-byte digest/encoding/bounded-input contract was not supplied by EPUBParserProtocol.contentForSpineItem, which returns String. EPUBParser decodes UTF-8 then Latin-1, uses a filename/size/mtime cache shared between instances, and open already extracts the first chapter plus starts detached resource extraction. ZIPReader has no caller-supplied decompression ceiling/cancellation contract. | Corrected in 00/01/02: add independent EPUBSemanticResourceReader returning verified raw bytes/encoding/digest, source-revision cache ownership, duplicate entry/path validation, actual decompression limits and cancellation. Preflight must precede any reused legacy open. Preserve the existing renderer-owned APIs and caches. WI-0 blocks implementation until feasibility/budgets are proven. |
| F2 | Low | Validation inventory said 714 files under vreaderTests without explaining excluded placeholders. | Corrected to 719 tracked files, including 694 Swift files, verified with git ls-files. Android test-path inventory remains 206 tracked files, including 205 Kotlin files. These are file counts, not successful-test counts. |
| F3 | Low | README/audit linked a review document that did not yet exist. | This artifact created; relative-link and code-fence validation must run after creation. |

Supporting paths for F1: [EPUBParserProtocol](../../vreader/Services/EPUB/EPUBParserProtocol.swift), [EPUBParser](../../vreader/Services/EPUB/EPUBParser.swift), [ZIPReader](../../vreader/Services/EPUB/ZIPReader.swift).

No remedy was rejected and no finding was disproven by performance measurement. A resource adapter is a proposed follow-up design, not code already made safe by these documentation corrections.

## Round 2

Independent rereview closed F1 and F2. No additional Critical/High/Medium findings were raised. The auditor's revised verdict was “foundation acceptable after the review artifact/link check,” with feature registration, parser fidelity/budgets and native testing remaining implementation prerequisites. F3 is closed by creation of this artifact and the author-run link check (five documents, 95 local links, all resolving). Final foundation verdict: acceptable for review/submission preparation; no implementation Gate 2 certification is claimed.

## Confirmed claims

- Actual EPUB dispatch uses paged Readium when enabled and legacy WKWebView for scroll; it is wired in ReaderContainerView/ReaderEngine, not just documented.
- iOS SchemaV10 and Android Room database 10 are live. The native Android implementation already exists.
- Existing annotations preserve EPUB DOM ranges, PDF normalized rectangles and text UTF-16 ranges; VReaderLocator retains authoritative Readium JSON.
- EPUB search extraction discards DOM structure. PDF search extraction collects page.string without semantic reading-order guarantees.
- Section/chapter context can include forward content; book-so-far without offsets can read all available text subject to its budget, and empty scopes can fall back to centered content.
- Current-book AI search lacks a cutoff and the inherited registry includes broad book-content/library tools. Strict retrieval needs a separately enforced policy across all context sources.
- AIService.sendRequest(_:using:) exists, checks live feature/consent gates at request entry, uses a resolved provider snapshot and bypasses the legacy provider-unaware cache.
- Converted-Kindle source identity handling exists in current import/model/migration source. Older contract implementation-status prose should not override that source.
- License inventory gaps and dependency pins described in the audit are supported by the tracked tree; no distribution-compliance conclusion is asserted.

Evidence paths and implications for these claims are listed in [00-repository-audit](00-repository-audit.md), rather than duplicated as another source of truth here.

## Native validation attempts

| Timing | Entry point | Result |
| --- | --- | --- |
| Before foundation edits | `bash scripts/run-tests.sh` | Exit 2: `RUN-TESTS RESULT: NO_BOOTED_SIM`. Linux has no xcrun/xcodebuild/Swift/XcodeGen. No XCTest suite executed. |
| Before foundation edits | `TIMEOUT_SECS=60 ANDROID_CMD='cd android && ./gradlew :identity:test --console=plain --no-daemon' bash scripts/run-android-tests.sh` | Exit 1: Gradle 8.14.4 download failed with `java.net.SocketException: Network is unreachable`; wrapper reports `RUN-ANDROID-TESTS RESULT: FAILED (exit 1)`. No identity tests executed. |
| After initial foundation edits | Same iOS test runner | Same exit 2/no booted simulator; no tests executed. |
| After initial foundation edits | Same Android identity command through watchdog | Same network/bootstrap failure; no identity tests executed. |

The final resource-reader corrections are documentation-only; native suites are not rerun after those corrections because the confirmed environment blockers are unchanged. No tests or production sources were modified. No test failure is classified as an application regression without an executing test suite.

## Local integrity checks

Passed: five documents with 95 local Markdown links resolving, balanced fenced blocks, no existing tracked production/configuration file modifications, and whitespace integrity via `git diff --check`. These checks establish document/worktree integrity only; they do not execute Swift/Kotlin code or render Mermaid.

## Submission and implementation prerequisites

- All files currently live as uncommitted documentation on the local branch. No push, GitHub issue, PR, merge, tag or release has been performed.
- AGENTS.md says “Do not commit unless explicitly requested.” Explicit submission instruction is needed before making a commit through either local Git or the GitHub API. The inherited version rule also requires a final patch bump and XcodeGen regeneration before a PR is opened; XcodeGen is currently absent.
- Feature registration, a fully specified parser/resource spike, a numbered implementation plan and independent formal Gate 2 are still required before TDD implementation. The foundation draft does not register or mark a feature complete.
- A capable Mac lane must execute iOS tests. Android identity/contract parity needs Gradle/dependency access. No hosted workflow is tracked in .github at the audited baseline.
