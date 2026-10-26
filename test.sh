#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
/usr/bin/xcrun swiftc -swift-version 5 Sources/Archive.swift Sources/StorageLocation.swift Tests/main.swift -o build/tests
build/tests
mkdir -p build/capture-timeout
/usr/bin/sed \
    -e 's/AXUIElementSetMessagingTimeout(/testSetTimeout(/g' \
    -e 's/AXUIElementCopyAttributeValue(/testCopyAttribute(/g' \
    -e 's/AXUIElementIsAttributeSettable(/testIsSettable(/g' \
    -e 's/AXUIElementCopyParameterizedAttributeValue(/testCopyParameterized(/g' \
    Sources/Capture.swift > build/capture-timeout/Capture.swift
/usr/bin/xcrun swiftc -swift-version 5 Sources/Archive.swift \
    build/capture-timeout/Capture.swift Tests/CaptureTimeout/main.swift -o build/capture-timeout/tests
build/capture-timeout/tests
