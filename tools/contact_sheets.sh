#!/bin/bash
# One contact sheet per menu across all UI themes: tools/contact_sheets.sh [<shots dir>]
# (reads <dir>/<theme>/<screen>.png as written by tools/shots_themes.tscn, writes <dir>/sheet_<screen>.png)
# tools/contact_sheets.sh charfix [<dir>]: one sheet per mode (run / jump / jet / scooter, side view) of the roster shots from tools/shots_charfix.tscn
if [ "$1" = "charfix" ]; then
	D=${2:-$HOME/Projects/arena-assets/shots/charfix/final}
	for mode in run jump jet scooter; do
		files=()
		for c in jimmy carl sheen cindy libby negatron ecarl esheen ecindy elibby; do [ -f "$D/${mode}_${c}_side.png" ] && files+=("$D/${mode}_${c}_side.png"); done
		[ ${#files[@]} -gt 0 ] || continue
		montage "${files[@]}" -tile 5x2 -geometry 512x288+4+4 -background '#202020' -title "$mode" -fill white "$D/sheet_$mode.png" && echo "sheet_$mode.png"
	done
	montage "$D"/sheet_run.png "$D"/sheet_jump.png "$D"/sheet_jet.png "$D"/sheet_scooter.png -tile 2x2 -geometry 1280x+6+6 -background '#202020' "$D/sheet_all.png" && echo "sheet_all.png"
	exit 0
fi
D=${1:-$HOME/Projects/arena-assets/shots/themes}
for screen in title setup join team loadout scoreboard hud; do
	files=()
	for t in lab negatron candy yokian cartoon; do [ -f "$D/$t/$screen.png" ] && files+=("$D/$t/$screen.png"); done
	[ ${#files[@]} -gt 0 ] || continue
	montage "${files[@]}" -tile 3x2 -geometry 640x360+6+6 -background '#202020' -title "$screen" -fill white "$D/sheet_$screen.png" && echo "sheet_$screen.png"
done
