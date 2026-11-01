extends SceneTree
## Headless full import for testing: godot --headless --path . -s tools/import_cli.gd -- <n2.iso> [<n1.iso>] --out=DIR --cache=DIR
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var isos: Array = []
	var out := "/tmp/na-import-out"
	var cache := "/tmp/na-import-cache"
	for a in args:
		if a.begins_with("--out="): out = a.substr(6)
		elif a.begins_with("--cache="): cache = a.substr(8)
		else: isos.append(a)
	var imp := NaImporter.new()
	var t0 := Time.get_ticks_msec()
	var r: Dictionary = imp.import_game(isos[0], isos[1] if isos.size() > 1 else "", out, cache)
	print("RESULT ", r, " wall ", (Time.get_ticks_msec() - t0) / 1000.0, "s")
	quit(0 if r.get("ok", false) else 1)
