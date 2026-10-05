#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if ! xcrun --find xcodebuild >/dev/null 2>&1; then
  echo "需要安装完整 Xcode，并在 Xcode 中安装 iOS Simulator 运行时。"
  exit 1
fi
plutil -lint Shanhe/Info.plist Shanhe/PrivacyInfo.xcprivacy Shanhe.xcodeproj/project.pbxproj
xcodebuild -project Shanhe.xcodeproj -scheme Shanhe -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
if [ $# -gt 0 ]; then
  xcodebuild -project Shanhe.xcodeproj -scheme Shanhe -configuration Debug \
    -destination "platform=iOS Simulator,id=$1" -derivedDataPath build \
    CODE_SIGNING_ALLOWED=NO test
else
  echo "模拟器编译完成。使用 bash verify-mac.sh <模拟器 UDID> 执行 XCTest。"
  xcrun simctl list devices available
fi
