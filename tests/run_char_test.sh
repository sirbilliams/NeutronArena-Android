#!/bin/bash
# Roster test: models load, +X facing, right-hand attach point, feet on the floor, red eyes.
cd "$(dirname "$0")/.."
timeout 240 flatpak run org.godotengine.Godot --headless --path . res://tests/char_test.tscn 2>&1 | grep -E "^==|^\s+\[|GAP|CHAR TEST|AnimFix|locked|SCRIPT ERROR|Parse Error|ERROR: [^R0-9P]" | grep -v -E "leaked|Leaked"
