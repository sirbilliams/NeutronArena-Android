#!/bin/bash
# Game modes: part 1 = pure rules (gun game ladder, CTF flag, KOTH zone, vote tally; needs no game files),
# part 2 = integration on a real host world with bots (needs the game files). Skip part 2 with FLOW=0.
cd "$(dirname "$0")/.."
OUT=$(timeout 90 flatpak run org.godotengine.Godot --headless --path . res://tests/modes_test.tscn 2>&1)
echo "$OUT" | grep -E "\[(ok|FAIL)\]|MODES TEST|SCRIPT ERROR|Parse Error|ERROR: [^R0-9P]" | grep -v -E "leaked|Leaked"
echo "$OUT" | grep -q "MODES TEST PASS" || exit 1
[ "${FLOW:-1}" = 0 ] && exit 0
PORT=${PORT:-24730}
OUT=$(timeout 120 flatpak run org.godotengine.Godot --headless --path . -- --test=md_flow --bots --port=$PORT --beacon_port=${BP:-7793} 2>&1)
echo "$OUT" | grep -E "^\s+\[(ok|FAIL)\]|MODES FLOW|SCRIPT ERROR|Parse Error" 
echo "$OUT" | grep -q "MODES FLOW PASS"
