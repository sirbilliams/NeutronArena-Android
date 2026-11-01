extends SceneTree
## Headless full import for testing: godot --headless --path . -s tools/import_cli.gd -- <n2.iso|folder> [<n1.iso|folder>] --out=DIR --cache=DIR
## A path that is a folder (already extracted game) goes through import_from_dirs; two ISOs through import_game.
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
	var n1: String = isos[1] if isos.size() > 1 else ""
	var r: Dictionary
	if DirAccess.dir_exists_absolute(isos[0]) and (n1 == "" or DirAccess.dir_exists_absolute(n1)):
		r = imp.import_from_dirs(isos[0], n1, out, cache)
	else:
		r = imp.import_game(isos[0], n1, out, cache)
	print("RESULT ", r, " wall ", (Time.get_ticks_msec() - t0) / 1000.0, "s")
	quit(0 if r.get("ok", false) else 1)
