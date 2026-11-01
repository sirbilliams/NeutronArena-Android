#!/bin/bash
# Real first-launch import through the setup screen (headless). Needs your own ISOs (never committed):
#   tests/run_setup_test.sh <neutron2 negatron.iso> [<boy genius bg.iso>]
cd "$(dirname "$0")/.."
N2=${1:-$HOME/Projects/neutron2-private/negatron.iso}; N1=${2:-$HOME/Projects/neutron1-private/bg.iso}
BAD=$HOME/Projects/na-test/bad.iso; mkdir -p $(dirname $BAD); head -c 100000 /dev/zero > $BAD
timeout 400 flatpak run --filesystem=$HOME/Projects org.godotengine.Godot --headless --path . res://tests/setup_test.tscn -- --n2=$N2 --n1=$N1 --bad=$BAD 2>&1 | grep -E "bad file|picked|wrong disc|import|SETUP TEST|SCRIPT ERROR|Parse"
rm -f $BAD
