# Feature179 — bounded native XML structural parser

Status: PLANNED; independent Gate2 PASS after2 rounds. Author: root; base8ac6931 (PR3 open).
This is the next independent foundational WI of the semantic extraction proposal.

## Problem and scope

Verified original EPUB bytes now exist in feature178, but there is no independent
native structural parser for future container/OPF/XHTML extraction. Add a bounded,
strict XML1.0 UTF-8 parser utility producing immutable logical node values, without
loading a book or depending on feature178 APIs. No package/spine/URI resolution,
semantic classification, whitespace folding, source-map/CFI, DOM navigation,
XML repair, HTML parsing, reader/AI/UI, persistence, Android or new dependency.
Malformed/unsupported input throws; no partial result or claimed recovery.
This WI proves native parser feasibility, not complete semantic extraction.

## File-by-file API

All Swift files <300lines; estimated800–1200 source/test lines total, split if needed.
- Services/Semantic/XML/SemanticXMLTypes.swift: immutable Sendable Equatable node
  values. Expanded element name(localName, namespaceURI, qualifiedName), lexical
  attribute dictionary keyed by qualified name (including explicit xmlns declarations),
  ordered children as integer indices,
  parent index; node kind(element/text/comment/processingInstruction). Document
  rootIndex plus flat nodes and raw input SHA256. Text is XML-decoded logical text,
  not original serialized byte positions. Adjacent character/CDATA callbacks under
  one parent coalesce into one logical text node. Comment/PI/element boundaries
  split text. Document-level comments/PI can be retained, parentnil; rootIndex
  identifies the sole element root. No node paths masquerade as browser DOM/CFI.
- SemanticXMLLimits.swift: positive lowerable hard ceilings at parse boundary:
  input4MiB, nodes50000, depth96(element root depth1), attributes128 per element,
  aggregate retained UTF16 units2Mi across names/URI/attribute keys+values/text/
  comments/PI (qualified/local fields count separately), declaration1024bytes.
  Nonthrowing initializer enables invalid configuration tests. Typed errors:
  invalidLimits, inputLimit, nodeLimit, depthLimit, attributeLimit, textLimit,
  unsupportedEncoding, forbiddenDTD, invalidXML, unimplemented(RED only).
- SemanticXMLPreflight.swift: input cap before decoding/hash/parser allocation;
  strict UTF8 with optional UTF8 BOM, reject NUL/UTF16/invalid sequences. XML
  declaration, if present, must be XML1.0 and encodingUTF-8 (case-insensitive
  encoding value); defaultsUTF8. Only bounded declaration regex, never structural
  regex extraction. Lexical byte walk rejects actual <!DOCTYPE / <!ENTITY outside
  comments/CDATA/PI before XMLParser sees input. Quote-aware tag scanning avoids
  mistaking attribute text for markup; malformed syntax still fails XMLParser.
  Cancellation checked every4096 scanned bytes, plus before/after decode/hash.
- SemanticXMLBuilder.swift: private-to-module NSObject/XMLParserDelegate used
  synchronously by one worker; Foundation XMLParser(data:), namespaces processed
  and prefixes reported, shouldResolveExternalEntities=false, external policynever;
  reject declaration callbacks as defense in depth, returnnil for external fetch.
  No external loader, URL-based constructor, scripts or HTML repair. Collect didStartMappingPrefix declarations for the upcoming element, storing
  `xmlns` / `xmlns:prefix` lexical keys and URI values (including empty default
  undeclaration). Charge their key/value UTF16 and count before pending retention.
  Merge with didStartElement ordinary attributes; callback/dictionary duplicates
  must agree and are charged once. Combined declarations+ordinary attributes
  obey the per-element cap. Pending declarations consumed once; end-mapping
  callbacks store no strings. No expanded attribute namespace claim. Count before
  retaining each node/string/attribute; cancellation every callback. parse abort
  keeps original typed/cancellation error; ignore partial node state on failure.
  XMLParser success AND no recorded error AND one root/full stack required.
- SemanticXMLParser.swift: static parse(_ bytes:Data, limits:) async throws ->
  SemanticXMLDocument; blocking worker creates/owns parser+builder, Task.detached
  receives Sendable inputs/results only. Parent cancellation forwards to child;
  check before parse, each event, afterparse and before publication. Internal
  Sendable observation callbacks synchronize real tests; no fake parse result or
  alternate byte source. parseBlocking remains internal for deterministic tests.
- Tests mirrored XML/: SemanticXMLParserTests, SemanticXMLSafetyTests,
  SemanticXMLCancellationTests. Shared helper under Helpers if needed.
- scripts/test-semantic-xml-contract.sh: exact source/test copy Swift6 nativeMac
  SwiftPM, no dependency download. .github/workflows/semantic-xml-contract.yml:
  stable Xcode, inputSHA/compiler evidence, positive executed test guard.
- Existing native-reader-check.yml extended for179 branch/new suite filters and
  explicit Passed node guard; preserve all178 guards, Debug/Release, raw logs,
  actual exit status, completed bundle/nonempty/fail0/skip0, isolated iPhone17Pro.
  Candidate version3.67.11 (1053), actual XcodeGen pair committed last afterproof.

Files OUT: all existing ZIP/EPUB readers, Models/locators, reader hosts, providers,
book import, domain/source-map/semantic classification, renderer and app schema.
Existing Sources auto-discovered by XcodeGen; production has no new call site.

## Prior art / parser choice / rejected alternatives

Apple XMLParser is available in Foundation on iOS/macOS without a new package.
Official contracts: callbacks may split character content; external resolution
policynever; CDATA callback supplies Data. We accumulate per logical node and
record deterministic own-tree semantics, not browser DOM equivalence.
https://developer.apple.com/documentation/foundation/xmlparser
https://developer.apple.com/documentation/foundation/xmlparserdelegate/parser(_:foundcharacters:)
https://developer.apple.com/documentation/foundation/xmlparser/externalentityresolvingpolicy-swift.enum/never
https://developer.apple.com/documentation/foundation/xmlparserdelegate/parser(_:foundcdata:)
XML1.0 logical line-end/entity normalization precedes logical text; no encoded-byte
mapping claim. https://www.w3.org/TR/xml/ . Existing Python prototype uses lxml;
its all-child text/tail selectors are NOT silently reused as native selectors.
Foundation SAX fits a strict bounded tree, cancellation per event and zero direct
package footprint. Direct libxml2 DOM would add pointer ownership/recovery policy;
Fuzi transitive lock pin is not app importability. Full DOM/HTML recovery and
source-map fidelity need a later decision; this parser proves only strict input.
Reject renderer DOM/WebView lifecycle, regex flattening, unlimited tree, and
repair-to-exact anchors. UTF16/otherencodings and DTD/XHTML named entities beyond
XML builtins are unsupported explicitly. No real-book compatibility claim.

## WI / dependencies / gates

One coherent foundational WI: independent plan audit(max3) → compile-capable stub
with behavioral native RED → implementation GREEN → independent audit(max3) →
Mac and actual iOS integration/compiler evidence → docs → generated pair tail → PR.
This parser consumes Data directly and imports no178 types, so its implementation
is independent of PR3 verification; the stacked branch preserves PR3 unchanged.
PR targets feature/178-native-epub-source-reader until PR3 is merged. Do not merge
or close either tracker automatically; future package/reader session work that
uses178+179 waits for those prerequisites to reach DONE/merged (rule48).
User authorized development branch commits and PRs; no release/tag is implied.

## Concrete test catalogue

Structure: empty element and rootIndex, default/prefixed namespace declaration
preservation, attribute-only prefixes, rebinding and xmlns=""; exact/over namespace
declaration count and UTF16 budgets; namespaces/prefixes/rebinding, qualified
attributes inclxml:lang, mixed parent text/child/tail, callback/entity coalescence,
CDATA/text combination, comments/PI split text, prolog/epilog comment/PI, retained
script/style and opaque table/MathML/SVG (no semantic filtering), determinism/hash.
Unicode: CJK, emoji/ZWJ, combining/NFD, RTL, numeric entities, builtins exactlyonce,
CR/CRLF normalization, escaped attribute spaces, UTF8 BOM and matching declaration.
Safety: empty/multiple root/unclosed/bad namespace/duplicate attribute/unknown
entity, NUL/invalidUTF8/UTF16/inconsistentencoding/XML1.1/huge declaration;
external file/http/parameter/internal expansion DTD, ENTITY declarations rejected
before parser; literal DOCTYPE in comment/CDATA/PI not rejected as declaration.
Budgets: invalidzero/negative/Intmax/default+1 limits, exact and over input/node/
depth/attributes/retainedUTF16 caps; text fragmentation cannot bypass totals;
comment/PI/attributes count too; input checked before unsafe parser work.
Cancellation: before parse, mid real callback, after actual detached worker starts,
pre-publication gate; bounded NSLock/semaphore5s probes observe real task forwarding,
no complete result, no builder sharing. Concurrent independent parses deterministic.
CI fixtures synthetic under exact-structure/CI exception, no fake parser acceptance.

## Acceptance / compatibility / risks

All cases pass after captured compile-success behavior RED; immutable output has
valid parent/child indices, one root, deterministic logical text and raw-byte hash.
Malformed/DTD/encoding/budget failures and cancellation publish no document. Real
Foundation parsing verified on Mac and iOS; all new suites explicitly executed,
Debug/Release pass; zero open auditCritical/High/Medium. Existing reading unchanged.
No UI/device book verification is claimed: rule47 foundational Gate5 exception.
No data/schema/backup change; no migration; default off by absence of call site.

Memory bounded by4MiB input plus bounded immutable tree/UTF16 payload; copies and
Foundation token buffers are bounded byinput, not a precise heap cap. Cancellation
is cooperative between scan units/callbacks; a single bounded token/parser call
may delay it, no hard CPU guarantee. Strict XML/UTF8 subset excludes common DTD
books and malformed XHTML; corpus/recovery/HTML/encoding compatibility is future
work, not a reason to silently change this contract. Source-node compatibility
with browser/CFI and source-text mapping remain unproved, not acceptance of179.

## Gate2 round1 correction

One Medium finding: namespace declaration retention/counting was underspecified.
Mapping callbacks now explicitly produce qualified xmlns dictionary entries,
charged before retention and combined with ordinary attributes once. Native tests
cover default/prefixed/attribute-only/rebound/empty declarations and limits.
No remedy rejected. Expanded attribute namespaces remain outside this WI.

Gate2 round2 independent PASS, no open findings. See .claude/codex-audits/plan-feature-179-gate2-audit.md.

## Gate3 executed RED

Native Swift6 run37120195492 at495756d3b1865c2ec71278b05b388f2dc0369920
compiles in10.93s;27 tests/3 suites fail82 issues on the unimplemented API.
Behavioral RED precedes implementation; cancelled-worker probes remain bounded.
Implementation adds worker-local Foundation delegate, mutable private drafts with
in-place text append (no per-callback whole-text copy), final immutable values,
pre-parser lexical security checks, namespace declaration accounting and forwarding
notification test seam. Actual native GREEN and source audit remain pending.

## Native implementation refinement

First Mac implementation run37120549878 compiles and runs all27 tests, but fails
four assertions: Foundation accepts undeclared element/attribute prefixes, and
its resolver callback for unknown references was classified as forbiddenDTD
instead of invalidXML. No GREEN claim. Add explicit qualified-name/reserved-prefix/
expanded-attribute-uniqueness validation in SemanticXMLNamespace.swift; it only
validates attributes, without adding expanded names to the output contract.
DTD declarations remain rejected before parsing; undeclared references are
malformed XML. Namespace regressions expanded to reserved/rebound aliases and
duplicate expanded attributes. The actual failing original tests remain intact.
