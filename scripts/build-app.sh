#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/taskvovsky-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
swift build --disable-sandbox --manifest-cache local -c release -debug-info-format none
destination="$(pwd)/build/Taskvovsky.app"
app="$(pwd)/build/.Taskvovsky-staging-$$.app"
trap 'rm -rf "$app"' EXIT
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
binary_dir="$(swift build --disable-sandbox --manifest-cache local -c release --show-bin-path)"
cp "$binary_dir/Taskvovsky" "$app/Contents/MacOS/Taskvovsky"
cp scripts/Info.plist "$app/Contents/Info.plist"
swift scripts/make-icon.swift "$app/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$app"
if [[ -d "$destination" ]]; then
    previous="$(pwd)/build/.Taskvovsky-previous-$$.app"
    mv "$destination" "$previous"
    mv "$app" "$destination"
    rm -rf "$previous"
else
    mv "$app" "$destination"
fi
echo "$destination"
