#!/usr/bin/env bash
# Purpose: Compile/test the exact EPUB, XML and package sources using native Swift6.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d -t epub-package-contract.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/Sources/vreader" "$WORK/Tests/vreaderTests"
cp "$ROOT"/vreader/Services/Semantic/XML/*.swift "$WORK/Sources/vreader/"
cp "$ROOT"/vreader/Services/Semantic/EPUB/*.swift "$WORK/Sources/vreader/"
cp "$ROOT"/vreader/Services/Semantic/Package/*.swift "$WORK/Sources/vreader/"
cp "$ROOT"/vreaderTests/Services/Semantic/Package/*.swift "$WORK/Tests/vreaderTests/"
cp "$ROOT/vreaderTests/Helpers/EPUBSemanticZIPFixture.swift" "$WORK/Tests/vreaderTests/"
cp "$ROOT/vreaderTests/Helpers/EPUBPackageFixture.swift" "$WORK/Tests/vreaderTests/"
cat > "$WORK/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "EPUBPackageContract", platforms: [.macOS(.v15)],
    products: [], targets: [.target(name: "vreader", linkerSettings: [.linkedLibrary("z")]),
        .testTarget(name: "vreaderTests", dependencies: ["vreader"])], swiftLanguageModes: [.v6])
SWIFT
swift test --package-path "$WORK" -Xswiftc -strict-concurrency=complete
