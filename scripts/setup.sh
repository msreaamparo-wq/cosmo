#!/usr/bin/env bash
# One-shot setup + verification for COSMOS (macOS / Linux / Git Bash). Run from the project root.
set -e
flutter --version
[ -d android ] && [ -d web ] || flutter create . --platforms=android,web --project-name cosmos
flutter pub get
dart run sqflite_common_ffi_web:setup     # copies sqlite3.wasm + sqflite_sw.js into web/
dart format .
flutter analyze
flutter test
echo "Setup finished. Run:  flutter run -d chrome   |   flutter run -d <android-device>"
