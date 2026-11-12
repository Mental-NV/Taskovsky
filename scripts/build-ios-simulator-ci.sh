#!/usr/bin/env bash
# Compile the checked-in iPhone app and test bundles, never run them.
set -euo pipefail
cd "$(dirname "$0")/.."
output="${1:-build/ci-ios}"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
test "$(uname -s)" = Darwin
test "$(uname -m)" = arm64
{
  printf 'tested_sha=%s\n' "$(git rev-parse HEAD)"
  printf 'developer_dir=%s\n' "${DEVELOPER_DIR:-default}"
  xcodebuild -version
  xcrun swift --version
  printf 'simulator_sdk='
  xcrun --sdk iphonesimulator --show-sdk-version
  printf 'destination=generic/platform=iOS Simulator\narchitecture=arm64\naction=build-for-testing (not test execution)\n'
} | tee "$output/provenance.log"
args=(-project Mobile/TaskovskyMobile.xcodeproj -scheme TaskovskyMobile
  -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator'
  -derivedDataPath "$output/DerivedData" ARCHS=arm64
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
{
xcodebuild "${args[@]}" -showBuildSettings -json > "$output/build-settings.json"
python3 - "$output/build-settings.json" <<'PY'
import json, sys
rows = json.load(open(sys.argv[1]))
app = [row['buildSettings'] for row in rows if row.get('target') == 'TaskovskyMobile']
if len(app) != 1:
    raise SystemExit('Expected exactly one TaskovskyMobile build settings record')
s = app[0]
for key, expected in [('PLATFORM_NAME', 'iphonesimulator'), ('IPHONEOS_DEPLOYMENT_TARGET', '17.0'), ('ARCHS', 'arm64'), ('CODE_SIGNING_ALLOWED', 'NO')]:
    if s.get(key) != expected:
        raise SystemExit(f'Unexpected {key}: {s.get(key)!r}; expected {expected!r}')
print('Resolved iPhone app deployment target: iOS 17.0; ARM64 simulator; signing disabled')
PY
} 2>&1 | tee "$output/settings-validation.log"
# A fresh output directory is required for each run; never delete prior evidence.
xcodebuild "${args[@]}" -resultBundlePath "$output/compile.xcresult" build-for-testing 2>&1 | tee "$output/compile.log"
python3 - "$output/DerivedData/Build/Products" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
app = root / 'Debug-iphonesimulator/TaskovskyMobile.app/TaskovskyMobile'
if not app.is_file():
    raise SystemExit('Missing compiled iPhone app executable')
for name in ('MobileContracts.xctest', 'MobileNavigation.xctest'):
    if not any(path.is_dir() for path in root.rglob(name)):
        raise SystemExit(f'Missing compiled test bundle: {name}')
if not any(root.glob('*.xctestrun')):
    raise SystemExit('Missing build-for-testing manifest')
print('App, contract/navigation test bundles and xctestrun manifest compiled; no tests executed')
PY
