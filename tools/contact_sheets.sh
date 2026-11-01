#!/bin/bash
# One contact sheet per menu across all UI themes: tools/contact_sheets.sh [<shots dir>]
# (reads <dir>/<theme>/<screen>.png as written by tools/shots_themes.tscn, writes <dir>/sheet_<screen>.png)
D=${1:-$HOME/Projects/arena-assets/shots/themes}
for screen in title setup join team loadout scoreboard hud; do
	files=()
	for t in lab negatron candy yokian cartoon; do [ -f "$D/$t/$screen.png" ] && files+=("$D/$t/$screen.png"); done
	[ ${#files[@]} -gt 0 ] || continue
	montage "${files[@]}" -tile 3x2 -geometry 640x360+6+6 -background '#202020' -title "$screen" -fill white "$D/sheet_$screen.png" && echo "sheet_$screen.png"
done
