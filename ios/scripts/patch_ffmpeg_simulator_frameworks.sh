#!/bin/bash
# Converts ffmpeg_kit_flutter_new_min device-only .framework binaries into
# .xcframeworks with arm64 iOS-simulator slices (required for iOS 26+ simulators).
set -euo pipefail

PLUGIN_IOS_DIR="${1:-}"
if [[ -z "$PLUGIN_IOS_DIR" || ! -d "$PLUGIN_IOS_DIR/Frameworks" ]]; then
  exit 0
fi

MARKER="$PLUGIN_IOS_DIR/Frameworks/.xcframework_simulator_patched"
if [[ -f "$MARKER" ]]; then
  exit 0
fi

if [[ ! -d "$PLUGIN_IOS_DIR/Frameworks/ffmpegkit.framework" ]]; then
  exit 0
fi

cd "$PLUGIN_IOS_DIR"

for fw in Frameworks/*.framework; do
  [[ -e "$fw" ]] || continue
  fwname=$(basename "$fw" .framework)
  fwpath="$fw/$fwname"

  lipo "$fwpath" -thin arm64 -output "/tmp/${fwname}_arm64"
  lipo "$fwpath" -thin x86_64 -output "/tmp/${fwname}_x86_64"
  if lipo "$fwpath" -thin arm64e -output "/tmp/${fwname}_arm64e" 2>/dev/null; then
    has_arm64e=1
  else
    has_arm64e=0
  fi

  xcrun vtool -set-build-version 7 12.1 18.5 -replace \
    -output "/tmp/${fwname}_arm64_sim" "/tmp/${fwname}_arm64"

  devdir="XCFramework/tmp/ios-arm64/$fwname.framework"
  mkdir -p "$devdir"
  cp -R "$fw/" "$devdir/"
  if [[ "$has_arm64e" -eq 1 ]]; then
    lipo "/tmp/${fwname}_arm64" "/tmp/${fwname}_arm64e" \
      -create -output "$devdir/$fwname"
  else
    cp "/tmp/${fwname}_arm64" "$devdir/$fwname"
  fi

  simdir="XCFramework/tmp/ios-arm64_x86_64-simulator/$fwname.framework"
  mkdir -p "$simdir"
  cp -R "$fw/" "$simdir/"
  lipo "/tmp/${fwname}_arm64_sim" "/tmp/${fwname}_x86_64" \
    -create -output "$simdir/$fwname"
  sed -i '' 's/iPhoneOS/iPhoneSimulator/g' "$simdir/Info.plist"

  xcodebuild -create-xcframework \
    -framework "$devdir" \
    -framework "$simdir" \
    -output "Frameworks/$fwname.xcframework"

  rm -f "/tmp/${fwname}_arm64" "/tmp/${fwname}_arm64e" \
        "/tmp/${fwname}_x86_64" "/tmp/${fwname}_arm64_sim"
  rm -rf "XCFramework/tmp"
done

rm -rf Frameworks/*.framework

PODSPEC="$PLUGIN_IOS_DIR/ffmpeg_kit_flutter_new_min.podspec"
if [[ -f "$PODSPEC" ]]; then
  sed -i '' "s/'EXCLUDED_ARCHS\[sdk=iphonesimulator\*\]' => 'i386 arm64'/'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'/g" "$PODSPEC"
  sed -i '' "s/\.framework'/.xcframework'/g" "$PODSPEC"
fi

touch "$MARKER"
