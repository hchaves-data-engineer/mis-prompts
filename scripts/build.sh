#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
mkdir -p .build dist
stage_dir="$(mktemp -d "$project_dir/.build/package.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
app_dir="$stage_dir/Mis Prompts.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp Resources/Seed.json "$app_dir/Contents/Resources/Seed.json"
build_arch="$(uname -m)"
swiftc -parse-as-library Sources/Core.swift Sources/App.swift \
  -target "${build_arch}-apple-macos14.0" -framework SwiftUI -framework AppKit \
  -O -o "$app_dir/Contents/MacOS/MisPrompts"
swift scripts/Icon.swift "$stage_dir/AppIcon.iconset"
iconutil -c icns "$stage_dir/AppIcon.iconset" -o "$app_dir/Contents/Resources/AppIcon.icns"
# File Provider may add this metadata to app bundles in synced folders.
if xattr "$app_dir" | grep -qx 'com.apple.FinderInfo'; then
  xattr -d com.apple.FinderInfo "$app_dir"
fi
codesign --force --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
ditto --norsrc --noextattr "$app_dir" "dist/Mis Prompts.app"
zip_path="dist/Mis-Prompts-1.0-macOS-${build_arch}.zip"
ditto -c -k --keepParent --norsrc --noextattr "$app_dir" "$zip_path"
printf 'Aplicación: %s/dist/Mis Prompts.app\nArchivo: %s/%s\n' "$project_dir" "$project_dir" "$zip_path"
