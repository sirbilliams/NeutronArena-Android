#!/bin/bash
# Headless localhost bot test: host (+9 bots, normal) and a client that joins later and replaces a bot.
cd "$(dirname "$0")/.."
G="flatpak run org.godotengine.Godot --headless --path ."
PORT=${PORT:-24710}
BP=${BP:-7791}
OUT=$(mktemp -d)
timeout 200 $G -- --test=bot_server --bots --difficulty=${DIFF:-normal} --port=$PORT --beacon_port=$BP > $OUT/s.log 2>&1 &
SP=$!
sleep 35
timeout 120 $G -- --test=bot_client --port=$PORT --beacon_port=$BP > $OUT/c.log 2>&1 &
CP=$!
wait $SP; S=$?; wait $CP; C=$?
for f in s c; do echo "== $f"; grep -E "^\s+\[|^\s+BOT|^\s+scoreboard|PASS|FAIL|SCRIPT ERROR|ERROR: [^R0-9]" $OUT/$f.log | grep -v -E "leaked|Leaked"; done
echo "exit codes: server=$S client=$C"
if [ $S = 0 ] && [ $C = 0 ]; then echo "BOT TEST PASS"; else echo "BOT TEST FAIL (logs in $OUT)"; exit 1; fi
