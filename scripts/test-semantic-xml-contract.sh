#!/usr/bin/env bash
# Purpose: Compile/test the exact independent XML sources using native Swift6.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d -t semantic-xml-contract.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/Sources/vreader" "$WORK/Tests/vreaderTests"
cp "$ROOT"/vreader/Services/Semantic/XML/*.swift "$WORK/Sources/vreader/"
cp "$ROOT"/vreaderTests/Services/Semantic/XML/*.swift "$WORK/Tests/vreaderTests/"
cp "$ROOT/vreaderTests/Helpers/SemanticXMLProbe.swift" "$WORK/Tests/vreaderTests/"
cat > "$WORK/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "SemanticXMLContract", platforms: [.macOS(.v15)],
    products: [], targets: [.target(name: "vreader"),
        .testTarget(name: "vreaderTests", dependencies: ["vreader"])], swiftLanguageModes: [.v6])
SWIFT
swift test --package-path "$WORK" -Xswiftc -strict-concurrency=complete
