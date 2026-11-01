#!/bin/bash
# Installs Godot's Android gradle build template into android/build (what the editor's "Install Android Build Template" does).
# Needed for the gradle export (Android plugin SharedImport). Not committed.
set -e
cd "$(dirname "$0")/.."
VER=${GODOT_VER:-4.7.2.stable}
ZIP=${GODOT_TEMPLATES:-$HOME/.var/app/org.godotengine.Godot/data/godot/export_templates/$VER}/android_source.zip
[ -f "$ZIP" ] || { echo "missing $ZIP"; exit 1; }
rm -rf android/build; mkdir -p android/build
unzip -q "$ZIP" -d android/build
echo -n "$VER" > android/.build_version
touch android/build/.gdignore
echo "template installed in android/build"
