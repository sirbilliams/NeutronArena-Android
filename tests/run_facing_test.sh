#!/bin/bash
cd "$(dirname "$0")/.." && timeout 120 flatpak run org.godotengine.Godot --headless --path . res://tests/facing_test.tscn 2>&1 | grep -E "AnimFix|fwd=|FACING|ERROR|SCRIPT"
