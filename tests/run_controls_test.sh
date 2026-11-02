#!/bin/bash
# Headless controls test: item cycling (L1/R1), R2 fires the selected gadget/ultimate (server-authoritative), gyro off/on.
cd "$(dirname "$0")/.."
OUT=$(mktemp)
timeout 120 flatpak run org.godotengine.Godot --headless --path . -- --test=ct_server --port=${PORT:-24730} --expect=1 > $OUT 2>&1
S=$?
grep -E "^\s+\[|PASS|FAIL|SCRIPT ERROR|Parse" $OUT
if [ $S = 0 ]; then echo "CONTROLS TEST PASS"; else echo "CONTROLS TEST FAIL (log $OUT)"; exit 1; fi
