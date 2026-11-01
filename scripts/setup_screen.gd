class_name SetupScreen
extends Control
## First-launch setup: the player picks their own game CD images and the app extracts + converts the art on the device
## (NaImporter, addons/naimport). Touch + gamepad friendly (big buttons, focus navigation). Nothing is ever uploaded or committed.
signal finished(ok: bool)

const MIN_FREE_BYTES := 300 * 1024 * 1024   # measured peak: cabinet copy ~133 MB + a few MB unpacked + ~5 MB output; headroom for the larger disc
var _paths := ["", ""]                      # 0 = Neutron vs Negatron (required), 1 = Boy Genius (optional)
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
var _imp: NaImporter
var _thread: Thread
var _result := {}
var _busy := false
var _dialog: FileDialog
var _can_go_back := false

func _init(can_go_back: bool = false) -> void:
	_can_go_back = can_go_back

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = Color(0.1, 0.12, 0.2); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var center := CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(center)
	var box := VBoxContainer.new(); box.custom_minimum_size = Vector2(760, 0); box.add_theme_constant_override("separation", 14); center.add_child(box)
	var title := Label.new(); title.text = "SET UP NEGATRON ARENA"; title.add_theme_font_size_override("font_size", 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(title)
	_info = Label.new(); _info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.text = "The game uses the art of your own copies of the PC games. Choose their CD images (.iso); everything is unpacked and converted on this device and stays here."
	box.add_child(_info)
	_add_row(box, 0, "Choose Neutron vs Negatron ISO  (required)")
	_add_row(box, 1, "Choose Boy Genius ISO  (optional, adds N1 gadgets)")
	_import_btn = Button.new(); _import_btn.text = "Import"; _import_btn.custom_minimum_size = Vector2(0, 64); _import_btn.disabled = true
	_import_btn.pressed.connect(_on_import); box.add_child(_import_btn)
	_prog_box = VBoxContainer.new(); _prog_box.visible = false; box.add_child(_prog_box)
	_stage_lbl = Label.new(); _prog_box.add_child(_stage_lbl)
	_stage_bar = ProgressBar.new(); _stage_bar.custom_minimum_size = Vector2(0, 26); _stage_bar.max_value = 1.0; _stage_bar.step = 0.001; _prog_box.add_child(_stage_bar)
	_all_bar = ProgressBar.new(); _all_bar.custom_minimum_size = Vector2(0, 26); _all_bar.max_value = 1.0; _all_bar.step = 0.001; _prog_box.add_child(_all_bar)
	_err = Label.new(); _err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _err.add_theme_color_override("font_color", Color(1, 0.45, 0.4)); box.add_child(_err)
	if _can_go_back:
		_back_btn = Button.new(); _back_btn.text = "Back"; _back_btn.custom_minimum_size = Vector2(0, 56)
		_back_btn.pressed.connect(func(): finished.emit(false)); box.add_child(_back_btn)
	_imp = NaImporter.new()
	(_edits[0].get_parent().get_child(0) as Button).grab_focus()

func _add_row(parent: Control, slot: int, text: String) -> void:
	var holder := VBoxContainer.new(); holder.add_theme_constant_override("separation", 4); parent.add_child(holder)
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(0, 64)
	b.pressed.connect(_pick.bind(slot)); holder.add_child(b)
	var e := LineEdit.new(); e.placeholder_text = "or type / paste the path of the .iso"; e.visible = OS.get_name() != "Android"
	e.text_submitted.connect(func(t): _set_path(slot, t.strip_edges())); e.focus_exited.connect(func(): _set_path(slot, e.text.strip_edges()))
	holder.add_child(e)
	var st := Label.new(); st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; holder.add_child(st)
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

func _set_path(slot: int, path: String) -> void:
	if path == "" or path == _paths[slot] and _ok[slot]: return
	_paths[slot] = path; _edits[slot].text = path
	_err.text = ""
	var r: Dictionary = _imp.probe_iso(path)
	_ok[slot] = r.get("ok", false)
	if _ok[slot]:
		_status[slot].text = "OK  -  %s%s" % [path.get_file() if not path.begins_with("content:") else "selected file", ("  (" + str(r["label"]) + ")") if r.has("label") else ""]
		_status[slot].remove_theme_color_override("font_color")
	else:
		_status[slot].text = str(r.get("error", "Can't read that file."))
		_status[slot].add_theme_color_override("font_color", Color(1, 0.45, 0.4))
	_import_btn.disabled = not _ok[0]

func _on_import() -> void:
	if _busy or not _ok[0]: return
	var tmp := ProjectSettings.globalize_path("user://import_tmp")
	var free: int = _imp.free_space(tmp)
	if free >= 0 and free < MIN_FREE_BYTES:
		_err.text = "Not enough free space: about %d MB are needed while importing (%d MB free)." % [MIN_FREE_BYTES / 1048576, free / 1048576]
		return
	_busy = true; _err.text = ""; _prog_box.visible = true; _import_btn.disabled = true
	_set_enabled(false)
	var out := Config.import_dir()
	DirAccess.remove_absolute(Config.IMPORT_URL.path_join("import.cfg"))
	_thread = Thread.new()
	_thread.start(_worker.bind(_paths[0], _paths[1] if _ok[1] else "", out, tmp))

func _worker(n2: String, n1: String, out: String, cache: String) -> void:
	_result = _imp.import_game(n2, n1, out, cache)
	_finished.call_deferred()

func _set_enabled(on: bool) -> void:
	for e in _edits: e.editable = on
	for c in find_children("*", "Button", true, false): (c as Button).disabled = not on
	if on: _import_btn.disabled = not _ok[0]

func _process(_d: float) -> void:
	if not _busy: return
	var p: Dictionary = _imp.get_progress()
	_stage_lbl.text = str(p.get("label", ""))
	_stage_bar.value = float(p.get("stage", 0.0)); _all_bar.value = float(p.get("overall", 0.0))

func _finished() -> void:
	_thread.wait_to_finish(); _busy = false; _set_enabled(true)
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
		_err.text = str(_result.get("error", "Import failed."))
		_prog_box.visible = false
