#!/bin/bash
# Headless localhost test: 1 server (host+player), 1 client, 1 observer. Prints PASS/FAIL per role + overall.
cd "$(dirname "$0")/.."
G="flatpak run org.godotengine.Godot --headless --path ."
PORT=${PORT:-24690}
OUT=$(mktemp -d)
timeout 150 $G -- --test=server --port=$PORT --expect=3 > $OUT/s.log 2>&1 &
SP=$!
sleep 6
timeout 140 $G -- --test=client --port=$PORT > $OUT/c.log 2>&1 &
CP=$!
(sleep 5; timeout 135 $G -- --test=observer --port=$PORT > $OUT/o.log 2>&1) &
OP=$!
wait $SP; S=$?; wait $CP; C=$?; wait $OP; O=$?
for f in s c o; do echo "== $f"; grep -E "^\s+\[|PASS|FAIL|SCRIPT ERROR|ERROR: [^R0-9]" $OUT/$f.log | grep -v -E "leaked|Leaked"; done
echo "exit codes: server=$S client=$C observer=$O"
if [ $S = 0 ] && [ $C = 0 ] && [ $O = 0 ]; then echo "NET TEST PASS"; else echo "NET TEST FAIL (logs in $OUT)"; exit 1; fi
