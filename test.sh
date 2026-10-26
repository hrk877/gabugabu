#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
/usr/bin/xcrun swiftc -swift-version 5 Sources/Archive.swift Sources/StorageLocation.swift Tests/main.swift -o build/tests
build/tests
