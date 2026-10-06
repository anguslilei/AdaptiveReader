# Feature181 — native semantic identities and logical source anchors

Status: PLANNED (Gate1+Gate2 PASS, two independent rounds). ID181 reserved by the actual
scripts/reserve-id.sh feature on2026-10-05. Prerequisite180 merged/DONE at54930d465d57cdce5699f36cf9edd14b222e3655
(PR5); Gate3 ready. Version allocation baseline is exactly this merge SHA.

## Problem / tier / boundaries

Native archive, XML and package utilities now identify the original resources and
spine occurrences, but no native semantic revision/ID/typed anchor values exist.
Provide deterministic, validated, immutable source identity primitives for the
next bounded XHTML extraction slice. This is one foundational PR, not extraction
or a user-observable feature. Pure values have no runtime book/open operation.

No SemanticDocument/block tree, inline classification, normalized text mapping,
byte-offset map, browser DOM/XPath, CFI, original-reader navigation, source resolver,
resource fetching, extraction session, metadata/layout policy, UI/AI/renderer/
search/SwiftData/backup/Android changes. Existing AnnotationAnchor and stored
locations are unchanged. No production caller is introduced. A syntactically valid
anchor does NOT establish that its node exists or that repaired XML matches source.

## Verified existing source and research

At236c014: Services/Semantic/EPUB owns immutable archive snapshots and lowerable
limits; source paths are literal strings. Package loader returns archiveSHA256,
containerSHA256, packagePath/packageSHA256, manifest items and every spine occurrence;
occurrences range0...4095 under its hard count4096. XML document owns sourceSHA256,
rootIndex and ordered nodes whose parent/children are integer indices; node kinds
include element/text/comment/PI. It is explicitly not a browser DOM/byte map.
XML hard depth96, aggregate textUTF16 2Mi; Foundation may coalesce logical text.
Models/Semantic does not exist; planned symbol names absent. AnnotationAnchor
imports CryptoKit and hashes canonical JSON, but is a separate persisted reader
contract. Reference prototype hashes an ordered explicit field tuple with source,
selector and occurrence; retain principle, do not claim identical wire identity.
project.yml uses Swift6; XcodeGen discovers files and targets automatically.

Primary prior art:
- Apple CryptoKit SHA256 (https://developer.apple.com/documentation/cryptokit/sha256).
  Existing compiled AnnotationAnchor verifies actual SHA256.hash(data:) API.
- Swift SE0166 (https://github.com/swiftlang/swift-evolution/blob/main/proposals/0166-swift-archival-serialization.md):
  custom init(from:) is necessary to route decoded fields through invariants;
  synthesized decoding alone directly assigns stored fields.
- EPUB CFI1.1 (https://idpf.org/epub/linking/cfi/epub-cfi-20170105.html), section3.1.4:
  offsets use UTF16 units; full CFI also requires package/document path semantics.
  This WI chooses compatible unit counting only, not CFI construction/conformance.
- Existing EPUBPackageLiteralKey UTF8 identity and byte slash splitting precedent.

Reject random UUIDs, text-only IDs, delimiter-joined strings, Swift Hasher output
as persisted IDs, JSONEncoder byte order as a canonical preimage, and normalization
of source paths. Reject reusing AnnotationAnchor/XPath/CFI for unproven selectors.
No new dependency: Foundation + platform CryptoKit on native Apple lanes.

## Files / exact interfaces

All new files under vreader/Models/Semantic/, each below300 lines, immutable let
fields, Sendable/Codable/Hashable unless explicitly noted. No memberwise bypass:
custom validated initializers and custom Decodable; encoded JSON is interchange
only, not the identity preimage. Derived fields are computed, not decoded.

| File / symbol | Contract |
| --- | --- |
| SemanticModelError.swift | Error, Sendable, Equatable: invalidDigest, unsupportedSchema, invalidVersion, invalidPath, invalidOccurrence, invalidNodePath, invalidRange, invalidOrdinal |
| SemanticSHA256.swift | init(hex:String)throws; hex:String. Exactly64 lowercase ASCII hex; single-value Codable; hex-to32-byte payload, no permissive upper/canonical normalization |
| SemanticArchivePath.swift | init(_ value:String)throws; value:String. Already resolved archive file path, literal UTF8 equality/hash, single-value Codable; no URL decoding |
| SemanticRevision.swift | init(archiveSHA256:SemanticSHA256, extractorVersion:Int, schemaVersion:Int=1)throws; schema exactly1; extractor1...UInt32.max. The version covers XML logical-tree/selection/extraction policy: changed policy requires a new extractorVersion |
| SemanticResourceIdentity.swift | init(path:SemanticArchivePath, sha256:SemanticSHA256); no additional throw; synthesized Codable safe only because both nested validated wrappers decode through custom initializers |
| SemanticUTF16Range.swift | init(lowerBound:Int,upperBound:Int)throws; 0<=lower<=upper<=2Mi. validate(in text:String)throws checks actual UTF16 bounds and forbids endpoints splitting a surrogate pair; zero-length and end-of-text allowed; combining/ZWJ boundaries allowed as scalar positions, not grapheme snapping |
| SemanticNodePath.swift | init(_ components:[Int])throws; components:[Int]. Root is []; at most96 child slots, each0...UInt32.max. custom unkeyed Decodable checks cap before appending, no decode-entire-unbounded-array convenience |
| SemanticLogicalAnchor.swift | init(resource:SemanticResourceIdentity, spineOccurrence:Int, nodePath:SemanticNodePath, textRange:SemanticUTF16Range?=nil)throws; occurrence0...4095. coordinateSystem:SemanticAnchorCoordinateSystem computed .semanticXMLTreeV1 (single frozen String enum case), not an exact/CFI claim, not encoded/decoded as source precision. Custom keyed decode invokes initializer; nil range denotes whole logical node |
| SemanticID.swift | init(hex:String)throws; hex:String; single-value Codable via SemanticSHA256. static revision(_ revision:SemanticRevision)->Self; section(revision:SemanticRevision,resource:SemanticResourceIdentity,spineOccurrence:Int)throws->Self; block(revision:SemanticRevision,anchor:SemanticLogicalAnchor,role:SemanticBlockRole,ordinal:Int)throws->Self. ordinal0...UInt32.max. SemanticBlockRole: heading,paragraph,figure,caption,quote,list,listItem,opaque with frozen explicit UInt8 tags1...8; no block payload or extractor |

Archive paths: UTF8 length1...8192; reject ASCII controls0...31/127, colon,
backslash, absolute/empty/repeated/trailing slash and exact ASCII dot/dotdot
components. Split ASCII47 bytes, independent of Swift Character graphemes.
Already-resolved filenames retain Unicode/case/percent/space literally. No percent
decode, escaping or query/fragment interpretation; literal ?/# may be represented
as archive filenames (this does not widen package URL acceptance). The8192 cap
is this model subset, not a claim of all valid ZIP filenames. No service import
or modification is needed; path shape is a separate pure model invariant.

Node paths are child SLOT indices in SemanticXMLDocument.nodes[parent].children,
starting at rootIndex and counting all retained logical children including text,
comments and PI. They are not flat node indices, CSS selectors, XPath or CFI
even/odd steps. A future resolver must bind revision/resource digest, extractor
version and actual original logical tree, verify each step and text-node/range
compatibility, and withhold exact positioning on repair/ambiguity. This WI only
represents syntax; no method claims resolution or source precision.

Stored value bounds/preimage size are finite; JSONDecoder may allocate its input
or decoded strings before wrapper validation. This is not a bounded JSON parser;
future external payload callers must bound raw input separately. Node path
decoding avoids unbounded retained array growth within this model itself.

## Canonical identity preimage v1 — explicit bytes

Prefix for every ID is ASCII "vreader.semantic-id.v1" plus NUL. Follow with one
kind byte: revision=1, section=2, block=3. Fixed integers are unsigned32 big endian.
All digests are decoded32 bytes, not64 ASCII. Strings have unsigned32 UTF8 byte
length followed by literal UTF8. No generic recursive/dictionary encoder.

Common revision fields in order: archiveDigest32, schemaVersionU32,
extractorVersionU32. Revision ID ends here.
Section adds resourcePath(length+UTF8), resourceDigest32, spineOccurrenceU32.
Block adds exactly those resource/occurrence fields from its anchor, then
nodePathCountU32 + each childSlotU32, textRangePresenceU8 (0=nil,1=present),
and iff present lowerU32/upperU32, roleU8, ordinalU32.
SHA256(preimage) rendered lowercase hex is the ID. Typed presence/length/kind/role
fields separate tuples; delimiters in filenames cannot create structural ambiguity.
All version/number/path bounds checked before conversion/allocation; no traps,
overflow or force-try in the public constructor/factory path.
CryptoKit's typed32-byte digest may construct a validated SemanticSHA256 through
a private known-digest path; no unchecked arbitrary String/array factory is exposed.

Archive-byte changes conservatively revise every ID, even if one chapter is
unchanged. Resource bytes/path, repeated spine occurrences, logical path/range,
role and ordinal distinguish blocks; equal paragraph text alone is irrelevant.
This is an application-defined v1 identity contract, not a standard CFI/hash wire
format or mathematical promise against SHA256 collision. Font/layout/reader goal
are absent from the tuple and cannot change identity for the same source inputs.
No serialization/hash of JSON presentation formatting. JSON decoding of an ID
validates its digest spelling only, not provenance of the tuple; factories establish
derived identity, while a future document validator must reject duplicates/tampering.

## Work item / test-first / verification

One PR: values +3 focused test suites + source-only Mac harness, small native
lane extension and docs/evidence. Approximately400-650 source lines across9 files,
350-550 test lines across3-4 files; all under300 individually.

Tests first compile against throwing placeholder constructors/factories, then
native Mac actual Swift6 behavioral RED (not a compiler failure). GREEN implements
only the audited invariants. Independent Python hashlib/struct test-vector script
produces fixed canonical bytes/hashes; checked-in vectors and tests must not call
production encoder to derive their expected digest. Vectors are explicit protocol
evidence, not a substitute for actual Swift execution. No book fixture necessary
for pure models; string cases use CI/exact-input exception.

| Suite | Concrete catalogue |
| --- | --- |
| SemanticIdentityTests | fixed revision/section/block vectors and full preimage bytes; repeatability/concurrent factories; domain separation; each source/version/occurrence/node/range/role/ordinal field change alters preimage/hash; delimiter filenames, CJK/emoji/RTL, literal NFC/NFD distinct; nil vs empty range; same text/different source nodes/repeated chapter occurrences; extractor upgrades; min/max UInt32; negative/Int.max/invalid occurrence/schema/version |
| SemanticSourceAnchorTests | digest empty/length/nonhex/upper/Unicode; path empty, absolute, slash+combining scalar, repeated/trailing/dot/dotdot, backslash/colon/control, exact8192/over, percent filename literal and ?/#; root/depth96/97, negative/UInt32.max/over child slots; occurrence0/4095/4096; UTF16 zero/end/emoji surrogate splits, combining/ZWJ/CJK/RTL/CRLF, out-of-text and2Mi boundaries; coordinate system stays logicalTree |
| SemanticModelCodableTests | every model round-trip preserves literal equality/hash; negative/out-of-cap/missing/null/wrong types/unknown schema/digest/path decode rejects through validating initializers; bounded path array decoder; Int.max and overflow inputs; frozen role encoding/unknown role rejects; generated ID decode rejects bad spelling; arbitrary valid-looking ID is not represented as proven source provenance |

Native Mac harness copies exact Models/Semantic and3 tests into SwiftPM with
Swift6 complete concurrency, Foundation/CryptoKit, no remote dependency. Own
readonly pinned-action macos15 workflow validates actual positive execution and
all3 suite footers. Before publishing CI syntax/bash checks are mandatory; the
previous one-parenthesis exporter mistake must not recur.

Native iPhone17Pro tests use original watchdog and isolated UDID. Existing base
reader/EPUB/XML, package, then model suites run as3 sequential disjoint invocations;
each lane owns status/start/full/wrapper/completed result/summary/tree, validates
before next starts, distinct bundle paths, positive all-passed typed counts,
failed/skipped0, exact device and explicit expected suite Passed nodes.
Add3 model suite aliases; preserve existing9-suite guards. Exporter allowlist adds
only6 model text members (full logs artifact-only), 8Mi decoded ceiling unchanged.
Debug/Release regression and source/tool/generation evidence retained.
Native workflow computes next patch/build from merged main at its actual slot;
actual generated project.yml/PBX pair copied exactly as final version tail.
No local Swift/Xcode available; own Mac CI is the compile/execution lane.

### Exact test/tooling write set and evidence contract (Gate2 round1 fixes)

| Path | Change / execution contract |
| --- | --- |
| vreaderTests/Models/Semantic/SemanticIdentityTests.swift | Swift Testing suite `SemanticIdentityTests` / display `Semantic identity canonical bytes`; hardcoded independent expected bytes and hashes, internal testable canonical-byte functions shared by factories |
| vreaderTests/Models/Semantic/SemanticSourceAnchorTests.swift | suite `SemanticSourceAnchorTests` / display `Semantic logical source anchors`; constructor and UTF16/literal-path boundaries |
| vreaderTests/Models/Semantic/SemanticModelCodableTests.swift | suite `SemanticModelCodableTests` / display `Semantic model validated decoding`; all decoding invariants |
| scripts/semantic-model-vectors.py | standard-library hashlib/struct independent generator; exact checked-in vectors verified with `--check` |
| dev-docs/verification/artifacts/feature-181/identity-vectors.json | fixed explicit inputs, full preimage hex and SHA256 for revision/section/block, including Unicode/nil/zero and boundary cases; Swift tests embed corresponding constants, no runtime fixture lookup |
| scripts/test-semantic-model-contract.sh | copies exact nine production model files and three tests to temporary SwiftPM Swift6 package; no dependencies beyond Foundation/CryptoKit; original command status and full log retained, checks positive executed tests and all three suite pass footers |
| .github/workflows/semantic-model-contract.yml | pinned checkout/upload actions, contents read, macos15; push `feature/181-native-semantic-identities`, PR to main; path filters cover Models/Semantic, model tests, this harness/workflow and vector script/JSON; uploads source commit, tool versions and unmodified full logs on success/failure |
| scripts/prepare-semantic-version.py | stdlib CLI `--baseline-yml --baseline-sha --input-yml --output-dir`; validates exactly one marketing/build field, positive integers, baseline patch/build +1, and input equals baseline or candidate; writes candidate project.yml plus baseline SHA/YML and version-allocation JSON; AST/positive/idempotency/unexpected-input checks before CI publication |
| .github/workflows/native-reader-check.yml | add exact feature181 push branch; replace fixed1054 generation for this branch with pinned merged-main allocation below; preserve existing old branch behavior, Debug/Release, original watchdog, isolated simulator and upload steps |
| scripts/test-native-semantic-foundations.sh | append model lane after validated base/package; exact selectors above; expected suite aliases as above; all three completed xcresult paths distinct; original device/count/status/footer guards unchanged |
| scripts/export-native-package-evidence.py | add Models/Semantic/**/*.swift, model tests/**/*.swift, all named new script/workflow/vector paths to source_paths; add six model text console members and baseline/allocation files to bounded explicit allowlist; model full log remains artifact-only |
| .claude/codex-audits/plan-feature-181-gate2-audit.md and feature-181-gate4-audit.md | every independent round enumerated with dispositions; no inherited feature180 waiver |
| docs/features.md, docs/architecture.md, docs/adaptive-reader/README.md, this plan, dev-docs/verification/feature-181-20261005.md | tracker/architecture/roadmap and actual evidence sync; project.yml and vreader.xcodeproj/project.pbxproj only in final generated version tail |

Exporter source evidence records checkout source_commit and per-file bytes,
SHA256 and git_blob_sha for ALL new models/tests/tools/vectors plus existing
semantic source/test/helper/tool paths. Missing named source paths fail export;
full build/test logs are still retained as artifact members with the same facts.
The six model console text members are command-status, result-path, start,
summary, tree and wrapper; full log is artifact-only. Common baseline text members
are version-baseline-sha.txt, version-baseline.yml and version-allocation.json.
Keep the existing decoded console total <=8MiB, not a per-file relaxation.

After PR5 merges, record its exact main merge SHA as feature181's expected
allocation baseline in the native workflow. Fetch main read-only in CI and verify
FETCH_HEAD equals that pinned SHA; if main advanced, fail and explicitly reconcile
the plan/allocation before rerunning. Read project.yml via `git show SHA:project.yml`
into preparation/version-baseline.yml, never infer versions from a branch's
mutable current version. Script derives baseline patch+1/build+1 once; accepts
either the original baseline input or already-allocated candidate so the final
version-tail rerun is idempotent. Record SHA, exact baseline YML and allocation
JSON with both input/candidate pairs. XcodeGen then emits the actual PBX project;
copy that precise generated project.yml/PBX pair as the last commit before PR.
No guessed version pair and no automatic second bump after copying the tail.
Mandatory syntax checks: bash -n on both harnesses, Python AST parse on exporter,
vector and version scripts, parse both changed workflow YAML; actual Mac RED then
GREEN and native positive suite/count guards remain required, not syntax alone.

### Audit revision history

- Round1: FAIL, two Medium findings. Fixed incomplete source evidence by naming
  every new source/tool/vector path and per-file facts. Fixed underspecified CI
  routes/version preparation with exact files, triggers, pinned baseline,
  one-time allocation, idempotency, generated pair and syntax/execution checks.
  No rejected findings or disproven-by-measurement claims.
- Round2: PASS, zero open findings of any severity. Independent audit confirmed
  both remedies and the model/anchor contract. Full committed audit artifact:
  .claude/codex-audits/plan-feature-181-gate2-audit.md. Gate3 prerequisite subsequently satisfied by PR5 merge.

### Gate4 audit-driven tooling addition

Round1 found one Medium in version-field uniqueness: numeric-only regex counts
missed duplicate quoted/commented fields. Fixed by counting mapping keys before
validating canonical numeric block values, including quoted/escaped keys and flow
overrides. Added scripts/__tests__/prepare-semantic-version.test.py (stdlib eight
tests,18 duplicate variants plus bounds/mixed pairs/real CLI/idempotency), run by
the existing Ubuntu native wrapper job and included in exporter source facts.
Actual pre-fix acceptance reproduced and post-fix rejection observed locally;
this is tooling regression evidence, not an XcodeGen override reproduction.
No model/API scope change; Gate4 round2 pending. No rejected finding or waiver.

## Risks / compatibility / acceptance

No storage/schema migration, persisted reader anchor change or user-facing
behavior. Models are dormant/disposable until later extraction caller lands.
No cancellation lifecycle added to bounded pure functions; no global mutable state.
Path hard cap and logical anchor limitations explicitly preserved. Parser policy
version changes require extractorVersion change before a selector is reused.
No repaired-tree exactness, normalized map, CFI, real-book or production reachability
claim. Downstream consumers must resolve and validate against verified originals.

Acceptance: actual compile-capable RED then GREEN; independent fixed vectors;
all syntax/boundary/Unicode/Codable cases pass; actual Mac3 suites and native3 model
suite nodes, prior9 semantic suites all pass with zero failed/skipped and
Debug/Release pass; zero open auditCritical/High/Medium; docs sync; actual generated
pair tail before PR. Foundational Gate5 is pure/native tests+audit, not a user UI
verification. Feature remains IN PROGRESS until merge, DONE afterward, never VERIFIED
without a later production-reachable feature. Fork Issues remain disabled; no
invented GH issue/Refs181. Maximum3 plan and implementation audit rounds apply.
