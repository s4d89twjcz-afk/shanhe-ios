#!/bin/bash
set -euo pipefail
projectRoot="$(cd "$(dirname "$0")" && pwd)"
cd "$projectRoot"
mkdir -p build/logs build/IPA
xcodebuild -version
plutil -lint Shanhe/Info.plist Shanhe/PrivacyInfo.xcprivacy Shanhe.xcodeproj/project.pbxproj
xcodebuild -project Shanhe.xcodeproj -scheme Shanhe -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$projectRoot/build/DerivedData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' build 2>&1 | tee build/logs/device-build.log
appBundle="$projectRoot/build/DerivedData/Build/Products/Release-iphoneos/Shanhe.app"
test -f "$appBundle/Shanhe"
platform=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleSupportedPlatforms:0' "$appBundle/Info.plist")
test "$platform" = 'iPhoneOS'
stageFolder=$(mktemp -d "$projectRoot/build/IPA/stage.XXXXXX")
mkdir "$stageFolder/Payload"
ditto "$appBundle" "$stageFolder/Payload/Shanhe.app"
ditto -c -k --keepParent "$stageFolder/Payload" "$projectRoot/build/IPA/Shanhe-unsigned.ipa"
unzip -t "$projectRoot/build/IPA/Shanhe-unsigned.ipa" > build/logs/ipa-check.log
if [ "${RUN_TESTS:-false}" = 'true' ]; then
  xcrun simctl list devices available -j > build/logs/simulators.json
  simulatorID=$(python3 - <<'PY'
import json
with open('build/logs/simulators.json') as stream:
    devices=json.load(stream)['devices']
for runtime, entries in devices.items():
    if '.iOS-' not in runtime:
        continue
    if int(runtime.rsplit('.iOS-', 1)[1].split('-')[0]) < 17:
        continue
    for entry in entries:
        if entry.get('isAvailable') and entry['name'].startswith('iPhone'):
            print(entry['udid'])
            raise SystemExit(0)
raise SystemExit('No available iPhone simulator runtime; install one in Xcode.')
PY
  )
  xcodebuild -project Shanhe.xcodeproj -scheme Shanhe -configuration Debug \
    -destination "platform=iOS Simulator,id=$simulatorID" -derivedDataPath "$projectRoot/build/Simulator" \
    CODE_SIGNING_ALLOWED=NO test 2>&1 | tee build/logs/simulator-tests.log
fi
echo 'Created build/IPA/Shanhe-unsigned.ipa. It must be signed by Sideloadly/AltStore before installation.'
