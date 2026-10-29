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
    -e 's/AXUIElementGetPid(/testGetPid(/g' \
    -e 's/AXUIElementCreateSystemWide(/testSystemWide(/g' \
    -e 's/AXUIElementSetAttributeValue(/testSetAttribute(/g' \
    Sources/Capture.swift > build/capture-timeout/Capture.swift
/usr/bin/xcrun swiftc -swift-version 5 Sources/Archive.swift Sources/CopySession.swift Sources/CopyCapture.swift \
    build/capture-timeout/Capture.swift Tests/CaptureTimeout/main.swift -o build/capture-timeout/tests
build/capture-timeout/tests
/usr/bin/xcrun swiftc -swift-version 5 Sources/CopySession.swift Tests/CopySession/main.swift -o build/copy-session-tests
build/copy-session-tests
/usr/bin/xcrun swiftc -swift-version 5 Sources/Archive.swift Sources/CopySession.swift Sources/CopyCapture.swift Sources/Capture.swift Tests/CopyBoard/main.swift -o build/copy-board-tests
build/copy-board-tests
