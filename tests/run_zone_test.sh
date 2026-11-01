#!/bin/bash
cd "$(dirname "$0")/.."
timeout 60 flatpak run org.godotengine.Godot --headless --path . res://tests/zone_test.tscn 2>&1 | grep -E "\[|ZONE TEST|SCRIPT ERROR|Parse"
