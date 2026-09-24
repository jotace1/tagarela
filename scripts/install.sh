#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_dir=$("$project_dir/scripts/bundle.sh" | tail -1)

pkill -f "/Applications/Tagarela.app" 2>/dev/null || true
for _ in {1..20}; do
    pgrep -f "/Applications/Tagarela.app" >/dev/null || break
    sleep 0.25
done

rm -rf "/Applications/Tagarela.app"
cp -R "$app_dir" /Applications/
open "/Applications/Tagarela.app"

echo "instalado $(plutil -extract CFBundleShortVersionString raw /Applications/Tagarela.app/Contents/Info.plist)"
