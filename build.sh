#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build dist/GABUGABU.app/Contents/MacOS dist/GABUGABU.app/Contents/Resources
for arch in arm64 x86_64; do
    /usr/bin/xcrun swiftc -swift-version 5 -O -target "${arch}-apple-macosx13.0" \
        Sources/Archive.swift Sources/StorageLocation.swift Sources/CopySession.swift Sources/CopyCapture.swift Sources/Capture.swift Sources/Toast.swift Sources/main.swift \
        -o "build/GABUGABU-${arch}"
done
/usr/bin/lipo -create build/GABUGABU-arm64 build/GABUGABU-x86_64 \
    -output dist/GABUGABU.app/Contents/MacOS/GABUGABU
/bin/cp Info.plist dist/GABUGABU.app/Contents/Info.plist
/bin/cp README.md dist/GABUGABU.app/Contents/Resources/使い方.md
/bin/cp LICENSE dist/GABUGABU.app/Contents/Resources/LICENSE
/bin/cp assets/AppIcon.icns dist/GABUGABU.app/Contents/Resources/AppIcon.icns
/usr/bin/codesign --force --sign - dist/GABUGABU.app
/usr/bin/ditto -c -k --sequesterRsrc --keepParent dist/GABUGABU.app dist/GABUGABU-1.4.0-mac.zip
echo 'Built: dist/GABUGABU.app and dist/GABUGABU-1.4.0-mac.zip'
