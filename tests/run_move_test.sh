#!/bin/bash
# Headless movement test (grounding, curbs, slopes, jump feel, remote interpolation) at 60 and 30 Hz physics.
cd "$(dirname "$0")/.."
timeout 400 flatpak run org.godotengine.Godot --headless --path . res://tests/move_test.tscn > ${MOVE_LOG:-/dev/stdout} 2>&1

