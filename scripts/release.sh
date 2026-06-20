#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

SKIP_CODEGEN=0
if [[ "${1:-}" == "--skip-codegen" ]]; then
  SKIP_CODEGEN=1
  shift
fi

flutter pub get

if [[ $SKIP_CODEGEN -eq 0 ]]; then
  # Codegen pipeline (equivalent to `scr build`)
  dart pub run flutter_oss_licenses:generate.dart
  dart run intl_utils:generate
  flutter pub run flutter_launcher_icons
  flutter pub run flutter_native_splash:create
  dart run build_runner build
fi

flutter build apk --release --target-platform android-arm64

APK="$(pwd)/build/app/outputs/flutter-apk/app-release.apk"

echo
echo "APK: $APK"

apksigner sign --ks ../my-debug.jks --ks-key-alias my-key --ks-pass "pass:$1" --v1-signing-enabled false --v2-signing-enabled true --v3-signing-enabled false --out my-app-signed.apk "$APK"
