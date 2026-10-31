#!/bin/bash
# Headless loadout test over localhost: host (shooter) + client (Negatron, picks loadouts) + observer.
cd "$(dirname "$0")/.."
G="flatpak run org.godotengine.Godot --headless --path ."
PORT=${PORT:-24710}
OUT=$(mktemp -d)
timeout 280 $G -- --test=lo_server --port=$PORT --expect=3 > $OUT/s.log 2>&1 &
SP=$!
sleep 6
timeout 270 $G -- --test=lo_client --port=$PORT > $OUT/c.log 2>&1 &
CP=$!
(sleep 5; timeout 265 $G -- --test=lo_observer --port=$PORT > $OUT/o.log 2>&1) &
OP=$!
wait $SP; S=$?; wait $CP; C=$?; wait $OP; O=$?
for f in s c o; do echo "== $f"; grep -E "^\s+\[|PASS|FAIL|SCRIPT ERROR|ERROR: [^R0-9P]" $OUT/$f.log | grep -v -E "leaked|Leaked"; done
echo "exit codes: server=$S client=$C observer=$O"
if [ $S = 0 ] && [ $C = 0 ] && [ $O = 0 ]; then echo "LOADOUT TEST PASS"; else echo "LOADOUT TEST FAIL (logs in $OUT)"; exit 1; fi
