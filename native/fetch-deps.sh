#!/bin/sh
# Fetches godot-cpp (MIT) next to this script; it is not committed.
cd "$(dirname "$0")"
[ -d godot-cpp ] || git clone --depth 1 --branch godot-4.5-stable https://github.com/godotengine/godot-cpp godot-cpp
