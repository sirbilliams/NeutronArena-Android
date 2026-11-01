extends Node
## Drives the real setup screen headless: picks the ISOs (paths from --n2= / --n1=), imports, checks the files + marker.
## godot --headless --path . res://tests/setup_test.tscn -- --n2=/path/negatron.iso [--n1=/path/bg.iso] [--bad=/path/not.iso]
func _ready() -> void:
	var n2 := ""; var n1 := ""; var bad := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n2="): n2 = a.substr(5)
		elif a.begins_with("--n1="): n1 = a.substr(5)
		elif a.begins_with("--bad="): bad = a.substr(6)
	var cfg = Config
	var scr := SetupScreen.new(false)
	add_child(scr)
	await get_tree().process_frame
	var fails := 0
	if bad != "":
		scr._set_path(0, bad)
		print("bad file -> ok=", scr._ok[0], " msg=", scr._status[0].text)
		if scr._ok[0]: fails += 1
		# a CD image of the other game must be refused with a clear message
		scr._set_path(1, n2)
	scr._ok = [false, false]; scr._paths = ["", ""]
	scr._set_path(0, n2)
	if n1 != "": scr._set_path(1, n1)
	print("picked: ", scr._status[0].text, " | ", scr._status[1].text)
	if not scr._ok[0]: fails += 1
	var t0 := Time.get_ticks_msec()
	scr._on_import()
	var flag := [false]
	scr.finished.connect(func(ok): flag[0] = ok)
	var last := ""
	while not flag[0] and Time.get_ticks_msec() - t0 < 300000:
		await get_tree().process_frame
		if scr._stage_lbl.text != last: last = scr._stage_lbl.text; print("  stage: ", last)
		if scr._err.text != "": break
	print("import: ", "done" if flag[0] else "FAILED " + scr._err.text, " in ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
	if not flag[0]: fails += 1
	print("imported_ok=", cfg.imported_ok(), " has_n1=", cfg.has_n1(), " asset_dir=", cfg.asset_dir)
	if not cfg.imported_ok(): fails += 1
	# wrong disc in the wrong slot: clear message
	if n1 != "":
		var w: Dictionary = NaImporter.new().import_game(n1, "", OS.get_user_data_dir().path_join("wrong_out"), OS.get_user_data_dir().path_join("wrong_cache"))
		print("wrong disc (Boy Genius as Neutron vs Negatron): ok=", w.get("ok"), " msg=", w.get("error"))
		if w.get("ok", true) or str(w.get("error", "")).find("other game") < 0: fails += 1
		w = NaImporter.new().import_game(n2, n2, OS.get_user_data_dir().path_join("wrong_out"), OS.get_user_data_dir().path_join("wrong_cache"))
		print("wrong disc (Negatron as Boy Genius): ok=", w.get("ok"), " msg=", w.get("error"))
		if w.get("ok", true) or str(w.get("error", "")).find("other game") < 0: fails += 1
	print("SETUP TEST ", "PASS" if fails == 0 else "FAIL")
	get_tree().quit(fails)
