#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="$project_dir/build/打卡时间.app"
contents_dir="$app_dir/Contents"
macos_dir="$contents_dir/MacOS"
cache_dir="$project_dir/.build-cache"

mkdir -p "$macos_dir" "$cache_dir"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"

clang \
  -fobjc-arc \
  -O \
  -fmodules-cache-path="$cache_dir" \
  -framework Cocoa \
  -framework CoreImage \
  -framework QuartzCore \
  -framework UniformTypeIdentifiers \
  "$project_dir"/Sources/WorkdayWidget/*.m \
  -o "$macos_dir/WorkdayWidget"

codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
