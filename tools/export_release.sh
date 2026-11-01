#!/bin/bash
# Release APK signed with Arena's own release key. The ports list its certificate digest as a knownSigner (Android 12+),
# so Android grants SharedImport read access to their game files.
#   tools/export_release.sh [signing folder]     default ~/.config/neutron-arena-signing (keystore *.keystore + file "password")
# The password is read from the file and handed to Godot through an environment block on a file descriptor
# (GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD); it is never echoed, put on a command line or written anywhere.
# Needs once: tools/setup_android_build.sh and tools/build_android_plugin.sh. Output: ~/Projects/arena-assets/build/neutron-arena-release.apk
set -e
cd "$(dirname "$0")/.."
DIR=${1:-$HOME/.config/neutron-arena-signing}
KS=$(ls "$DIR"/*.keystore | head -1)
[ -f "$KS" ] && [ -f "$DIR/password" ] || { echo "no keystore/password in $DIR"; exit 1; }
ALIAS=${ARENA_KEY_ALIAS:-arena}
mkdir -p "$HOME/Projects/arena-assets/build"
[ -f addons/sharedimport/bin/sharedimport.aar ] || tools/build_android_plugin.sh
exec 3< <(printf 'GODOT_ANDROID_KEYSTORE_RELEASE_PATH=%s\0GODOT_ANDROID_KEYSTORE_RELEASE_USER=%s\0GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=%s\0' \
  "$KS" "$ALIAS" "$(tr -d '\r\n' < "$DIR/password")")
timeout 900 flatpak run --env-fd=3 --filesystem="$HOME/Projects" --filesystem="$DIR:ro" org.godotengine.Godot \
  --headless --path . --export-release "Android Thor Release" "$HOME/Projects/arena-assets/build/neutron-arena-release.apk" 2>&1 | grep -v -i "password" | tail -15
exec 3<&-
