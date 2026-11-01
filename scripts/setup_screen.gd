class_name SetupScreen
extends Control
## First-launch setup: the player picks their own game CD images and the app extracts + converts the art on the device
## (NaImporter, addons/naimport). Touch + gamepad friendly (big buttons, focus navigation). Nothing is ever uploaded or committed.
signal finished(ok: bool)

const MIN_FREE_BYTES := 300 * 1024 * 1024   # measured peak: cabinet copy ~133 MB + a few MB unpacked + ~5 MB output; headroom for the larger disc
var _paths := ["", ""]                      # 0 = Neutron vs Negatron (required), 1 = Boy Genius (optional): .iso path, or an extracted game folder (desktop)
var _app := ["", ""]                        # package of an installed port app used instead (SharedSources), "" = none
var _is_dir := [false, false]
var _sources: Array = []
var _copying := false
var _ok := [false, false]
var _status: Array[Label] = []
var _edits: Array[LineEdit] = []
var _import_btn: Button
var _back_btn: Button
var _info: Label
var _err: Label
var _stage_lbl: Label
var _stage_bar: ProgressBar
var _all_bar: ProgressBar
var _prog_box: VBoxContainer
var _cancel_btn: Button
var _imp: NaImporter
var _thread: Thread
var _result := {}
var _busy := false
var _dialog: FileDialog
var _dir_dialog: FileDialog
var _can_go_back := false

func _init(can_go_back: bool = false) -> void:
	_can_go_back = can_go_back

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiBackground.new(true))
	var center := CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(center)
	var card := PanelContainer.new(); card.theme_type_variation = &"MenuPanel"; card.custom_minimum_size = Vector2(820, 0); center.add_child(card)
	var box := VBoxContainer.new(); card.add_child(box)
	var title := Label.new(); title.text = "SET UP NEUTRON ARENA"; title.theme_type_variation = &"Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(title)
	_info = Label.new(); _info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _info.theme_type_variation = &"Subtitle"
	_info.text = "The game uses the art of your own copies of the PC games: use the installed port apps if you have them, or choose the CD images (.iso). Everything is converted on this device and stays here."
	box.add_child(_info)
	_sources = SharedSources.installed()
	var cols := HBoxContainer.new(); box.add_child(cols)
	_add_row(cols, 0, "Choose the Neutron vs Negatron ISO")
	_add_row(cols, 1, "Choose the Boy Genius ISO")
	box.add_child(HSeparator.new())
	_import_btn = Button.new(); _import_btn.text = "IMPORT"; _import_btn.theme_type_variation = &"PrimaryButton"; _import_btn.custom_minimum_size = Vector2(0, 60); _import_btn.disabled = true
	_import_btn.pressed.connect(_on_import); box.add_child(_import_btn)
	_prog_box = VBoxContainer.new(); _prog_box.visible = false; box.add_child(_prog_box)
	_stage_lbl = Label.new(); _stage_lbl.theme_type_variation = &"Info"; _prog_box.add_child(_stage_lbl)
	_stage_bar = ProgressBar.new(); _stage_bar.theme_type_variation = &"ImportBar"; _stage_bar.custom_minimum_size = Vector2(0, 18); _stage_bar.max_value = 1.0; _stage_bar.step = 0.001; _prog_box.add_child(_stage_bar)
	_all_bar = ProgressBar.new(); _all_bar.theme_type_variation = &"ImportBar"; _all_bar.custom_minimum_size = Vector2(0, 18); _all_bar.max_value = 1.0; _all_bar.step = 0.001; _prog_box.add_child(_all_bar)
	_cancel_btn = Button.new(); _cancel_btn.text = "Cancel import"; _cancel_btn.theme_type_variation = &"SmallButton"; _cancel_btn.custom_minimum_size = Vector2(0, 44)
	_cancel_btn.pressed.connect(func(): _imp.cancel()); _prog_box.add_child(_cancel_btn)
	_err = Label.new(); _err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _err.theme_type_variation = &"Danger"; _err.visible = false; box.add_child(_err)
	if _can_go_back:
		_back_btn = Button.new(); _back_btn.text = "Back"; _back_btn.theme_type_variation = &"SmallButton"; _back_btn.custom_minimum_size = Vector2(0, 48)
		_back_btn.pressed.connect(func(): finished.emit(false)); box.add_child(_back_btn)
	_imp = NaImporter.new()
	for c in _edits[0].get_parent().get_children():
		if c is Button:
			c.grab_focus(); break

func _add_row(parent: Control, slot: int, text: String) -> void:
	var card := PanelContainer.new(); card.theme_type_variation = &"ListPanel"; card.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(card)
	var holder := VBoxContainer.new(); holder.add_theme_constant_override("separation", 6); card.add_child(holder)
	var head := Label.new(); head.text = "Neutron vs Negatron" if slot == 0 else "Boy Genius  (optional)"
	head.theme_type_variation = &"Heading"; head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; holder.add_child(head)
	var game := 2 if slot == 0 else 1
	for src in _sources:   # installed port apps come first
		if src["game"] != game: continue
		var ab := Button.new(); ab.text = "Use files from %s (installed)" % src["name"]; ab.custom_minimum_size = Vector2(0, 56)
		ab.pressed.connect(_pick_app.bind(slot, src)); holder.add_child(ab)
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(0, 56)
	b.pressed.connect(_pick.bind(slot)); holder.add_child(b)
	if OS.get_name() != "Android":
		var db := Button.new(); db.text = "…or choose an extracted game folder"; db.theme_type_variation = &"SmallButton"; db.custom_minimum_size = Vector2(0, 44)
		db.pressed.connect(_pick_dir.bind(slot)); holder.add_child(db)
	var e := LineEdit.new(); e.placeholder_text = "or type / paste the path of the .iso"; e.visible = OS.get_name() != "Android"
	e.text_submitted.connect(func(t): _set_path(slot, t.strip_edges())); e.focus_exited.connect(func(): _set_path(slot, e.text.strip_edges()))
	holder.add_child(e)
	var st := Label.new(); st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; st.theme_type_variation = &"Dim"; st.custom_minimum_size = Vector2(0, 24); holder.add_child(st)
	_status.append(st); _edits.append(e)

func _pick(slot: int) -> void:
	if _busy: return
	var filters := PackedStringArray(["*.iso,*.ISO ; CD images"])
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		var cb := func(ok: bool, files: PackedStringArray, _filter: int): if ok and files.size() > 0: _set_path.call_deferred(slot, files[0])
		var err := DisplayServer.file_dialog_show("Choose the CD image", "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, filters, cb)
		if err == OK: return
	# no native picker: Godot's own file dialog (desktop)
	if _dialog == null:
		_dialog = FileDialog.new(); _dialog.access = FileDialog.ACCESS_FILESYSTEM; _dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.filters = PackedStringArray(["*.iso,*.ISO ; CD images"]); _dialog.use_native_dialog = false
		_dialog.size = Vector2i(900, 600); add_child(_dialog)
	for c in _dialog.file_selected.get_connections(): _dialog.file_selected.disconnect(c["callable"])
	_dialog.file_selected.connect(func(p): _set_path(slot, p))
	_dialog.popup_centered()

func _pick_app(slot: int, src: Dictionary) -> void:
	if _busy: return
	_set_err("")
	_paths[slot] = ""; _edits[slot].text = ""; _is_dir[slot] = false
	if not src["ok"]:
		_app[slot] = ""; _ok[slot] = false
		_status[slot].text = src["error"]
		_status[slot].theme_type_variation = &"Danger"
	else:
		_app[slot] = src["pkg"]; _ok[slot] = true
		_status[slot].text = "OK  -  files from %s (installed)" % src["name"]
		_status[slot].theme_type_variation = &"Success"
	_import_btn.disabled = not _ok[0]

func _pick_dir(slot: int) -> void:
	if _busy: return
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		var cb := func(ok: bool, files: PackedStringArray, _filter: int): if ok and files.size() > 0: _set_path.call_deferred(slot, files[0])
		if DisplayServer.file_dialog_show("Choose the extracted game folder", "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_DIR, PackedStringArray(), cb) == OK: return
	if _dir_dialog == null:
		_dir_dialog = FileDialog.new(); _dir_dialog.access = FileDialog.ACCESS_FILESYSTEM; _dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_dir_dialog.use_native_dialog = false; _dir_dialog.size = Vector2i(900, 600); add_child(_dir_dialog)
	for c in _dir_dialog.dir_selected.get_connections(): _dir_dialog.dir_selected.disconnect(c["callable"])
	_dir_dialog.dir_selected.connect(func(p): _set_path(slot, p))
	_dir_dialog.popup_centered()

## Case-insensitive file/dir lookup in a folder.
static func _has_ci(dir: String, name: String) -> bool:
	for n in DirAccess.get_files_at(dir) + DirAccess.get_directories_at(dir):
		if n.to_lower() == name.to_lower(): return true
	return false

func _probe_dir(slot: int, path: String) -> Dictionary:
	var exe := "Neutron2.exe" if slot == 0 else "Neutron.exe"
	if not DirAccess.dir_exists_absolute(path): return {"ok": false, "error": "That isn't a folder."}
	if not _has_ci(path, exe) or not _has_ci(path, "ase"):
		return {"ok": false, "error": "That folder doesn't look like the extracted %s game (no %s)." % ["Neutron vs. Negatron" if slot == 0 else "Boy Genius", exe]}
	return {"ok": true, "label": "folder"}

func _set_path(slot: int, path: String) -> void:
	if path == "" or path == _paths[slot] and _ok[slot]: return
	_paths[slot] = path; _edits[slot].text = path; _app[slot] = ""
	_set_err("")
	_is_dir[slot] = DirAccess.dir_exists_absolute(path)
	var r: Dictionary = _probe_dir(slot, path) if _is_dir[slot] else _imp.probe_iso(path)
	_ok[slot] = r.get("ok", false)
	if _ok[slot]:
		_status[slot].text = "OK  -  %s%s" % [path.get_file() if not path.begins_with("content:") else "selected file", ("  (" + str(r["label"]) + ")") if r.has("label") else ""]
		_status[slot].theme_type_variation = &"Success"
	else:
		_status[slot].text = str(r.get("error", "Can't read that file."))
		_status[slot].theme_type_variation = &"Danger"
	_import_btn.disabled = not _ok[0]

func _on_import() -> void:
	if _busy or not _ok[0]: return
	var tmp := ProjectSettings.globalize_path("user://import_tmp")
	var free: int = _imp.free_space(tmp)
	if free >= 0 and free < MIN_FREE_BYTES:
		_set_err("Not enough free space: about %d MB are needed while importing (%d MB free)." % [MIN_FREE_BYTES / 1048576, free / 1048576])
		return
	_busy = true; _set_err(""); _prog_box.visible = true; _import_btn.disabled = true; _import_btn.visible = false
	_set_enabled(false)
	var out := Config.import_dir()
	DirAccess.remove_absolute(Config.IMPORT_URL.path_join("import.cfg"))
	_thread = Thread.new()
	var srcs := [{"path": _paths[0], "app": _app[0], "dir": _is_dir[0]}, {"path": _paths[1], "app": _app[1], "dir": _is_dir[1]} if _ok[1] else {}]
	_thread.start(_worker.bind(srcs, out, tmp))

func _worker(srcs: Array, out: String, cache: String) -> void:
	var plain: bool = srcs[0]["app"] == "" and not srcs[0]["dir"] and (srcs[1].is_empty() or (srcs[1]["app"] == "" and not srcs[1]["dir"]))
	if plain:   # both from ISO: the one-pass path
		_result = _imp.import_game(srcs[0]["path"], srcs[1]["path"] if not srcs[1].is_empty() else "", out, cache)
		_finished.call_deferred(); return
	# mixed: bring each game into a folder (app copy / ISO extraction / the player's own folder), then convert from the folders
	var dirs := ["", ""]
	var used_iso := false
	for i in 2:
		var s: Dictionary = srcs[i]
		if s.is_empty(): continue
		var dest := cache.path_join("app_n%d" % (2 if i == 0 else 1))
		if s["app"] != "":
			_copying = true
			var r := SharedSources.copy_from(s["app"], 2 if i == 0 else 1, dest)
			_copying = false
			if not r.get("ok", false): _result = {"ok": false, "error": str(r.get("error", "Couldn't copy the files from the app."))}; _cleanup(cache); _finished.call_deferred(); return
			dirs[i] = dest
		elif s["dir"]:
			dirs[i] = s["path"]
		else:
			used_iso = true
			var r: Dictionary = _imp.extract_iso(s["path"], 2 if i == 0 else 1, dest, cache)
			if not r.get("ok", false): _result = r; _cleanup(cache); _finished.call_deferred(); return
			dirs[i] = dest
	_result = _imp.import_from_dirs(dirs[0], dirs[1], out, cache, 0.3 if used_iso else 0.1)
	_cleanup(cache)
	_finished.call_deferred()

func _cleanup(cache: String) -> void:
	for n in ["app_n2", "app_n1", "cab"]:
		_rmtree(cache.path_join(n))

static func _rmtree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	for f in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(f))
	for d in DirAccess.get_directories_at(path): _rmtree(path.path_join(d))
	DirAccess.remove_absolute(path)

func _set_err(msg: String) -> void:
	_err.text = msg; _err.visible = msg != ""

func _set_enabled(on: bool) -> void:
	for e in _edits: e.editable = on
	for c in find_children("*", "Button", true, false): (c as Button).disabled = not on
	_cancel_btn.disabled = on
	if not on: _cancel_btn.grab_focus()
	if on: _import_btn.disabled = not _ok[0]

func _process(_d: float) -> void:
	if not _busy: return
	var p: Dictionary = _imp.get_progress()
	if _copying:
		var cp := SharedSources.progress()
		var tot := maxf(1.0, float(cp.get("total", 1)))
		p = {"label": "Copying %s" % str(cp.get("current", "")), "stage": float(cp.get("done", 0)) / tot, "overall": 0.1 * float(cp.get("done", 0)) / tot}
	_stage_lbl.text = str(p.get("label", ""))
	_stage_bar.value = float(p.get("stage", 0.0)); _all_bar.value = float(p.get("overall", 0.0))

func _finished() -> void:
	_thread.wait_to_finish(); _busy = false; _set_enabled(true); _import_btn.visible = true
	if _result.get("ok", false):
		var cf := ConfigFile.new()
		cf.set_value("import", "version", Config.IMPORT_VERSION)
		cf.set_value("import", "n1", _result.get("n1", false))
		cf.set_value("import", "seconds", _result.get("seconds", 0.0))
		cf.save(Config.IMPORT_URL.path_join("import.cfg"))
		Config.use_imported()
		_stage_lbl.text = "Done"; _all_bar.value = 1.0; _stage_bar.value = 1.0
		finished.emit(true)
	else:
		_set_err(str(_result.get("error", "Import failed.")))
		_prog_box.visible = false
