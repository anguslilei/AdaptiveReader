undefined

## AdaptiveReader native package/order foundation (feature180)

`EPUBSemanticPackageLoader` composes the real immutable archive reader and bounded
Foundation XML parser on a detached worker. It reads only `META-INF/container.xml`
and the single selected OPF, returning immutable archive/container/package SHA256
identities, ordered manifest entries and every spine occurrence (including repeated
idrefs and `linear=false`). No chapter resource is inflated. The reader's read-only
catalog exposes UTF8-literal sorted file paths and archive identity without I/O,
inflation or byte-budget consumption; manifest validation checks exact file
existence, not chapter CRC/content.

Container full-path URLs resolve once from the archive root; manifest hrefs
resolve once against the already-decoded OPF path. Strict UTF8 percent decoding,
ASCII slash segmentation, explicit dot-segment containment and terminal-directory
rejection avoid convenience-URL normalization and Unicode grapheme ambiguity.
IDs, paths, namespace names and property tokens use literal UTF8 identity,
including DTO equality. Spine resources must be XHTML; other non-spine media
are retained. Independent lowerable hard caps bound manifest/spine counts (4096),
properties (64), retained DTO UTF16 (2Mi) and catalog UTF16 (a separate 2Mi).
Existing source and XML limits remain independently validated.

Parent cancellation forwards to the actual worker/reader/parser. Every post-open
exit awaits reader closure; successful publication also follows closure. Tests
observe the actual actor and worker without substituting bytes or decoder results.
The native harness runs legacy reader/EPUB/XML and package suites sequentially on
one isolated simulator, retaining and validating each actual result bundle.

This is a bounded local structural subset, not a complete EPUB/WHATWG validator.
Repeated idrefs deliberately preserve nonconforming source input. It does not
interpret metadata/layout policy or add import, renderer, UI, persistence, AI,
source-map, CFI or DOM integration. The upstream ZIP index still rejects
canonically equivalent distinct filenames; literal package lookup prevents
substitution without widening that acceptance. Chapter extraction is a later WI.
See the [plan](../dev-docs/plans/20261003-feature-180-native-epub-package.md) and
[verification](../dev-docs/verification/feature-180-20261004.md).
