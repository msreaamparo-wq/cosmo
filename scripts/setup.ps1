# One-shot setup + verification for COSMOS (Windows PowerShell). Run from the project root.
$ErrorActionPreference = "Stop"
flutter --version
if (-not ((Test-Path android) -and (Test-Path web))) { flutter create . --platforms=android,web --project-name cosmos }
flutter pub get
dart run sqflite_common_ffi_web:setup     # copies sqlite3.wasm + sqflite_sw.js into web/
dart format .
flutter analyze
flutter test
Write-Host "Setup finished. Run:  flutter run -d chrome   |   flutter run -d <android-device>"
