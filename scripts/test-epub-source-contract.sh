#!/usr/bin/env bash
# Purpose: Compile/test exact independent semantic sources using the installed native Swift6 toolchain.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d -t epub-source-contract.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/Sources/vreader" "$WORK/Tests/vreaderTests"
cp "$ROOT"/vreader/Services/Semantic/EPUB/*.swift "$WORK/Sources/vreader/"
cp "$ROOT"/vreaderTests/Services/Semantic/EPUB/*.swift "$WORK/Tests/vreaderTests/"
cp "$ROOT/vreaderTests/Helpers/EPUBSemanticZIPFixture.swift" "$WORK/Tests/vreaderTests/"
cat > "$WORK/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "EPUBSourceContract", platforms: [.macOS(.v15)],
    products: [], targets: [
        .target(name: "vreader", linkerSettings: [.linkedLibrary("z")]),
        .testTarget(name: "vreaderTests", dependencies: ["vreader"],
                    linkerSettings: [.linkedLibrary("z")])
    ], swiftLanguageModes: [.v6])
SWIFT
swift test --package-path "$WORK" -Xswiftc -strict-concurrency=complete
