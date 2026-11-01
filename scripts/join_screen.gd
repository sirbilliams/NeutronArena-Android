class_name JoinScreen
extends Control
## Join screen: LAN games found by the beacon as big buttons (touch + gamepad), manual IP as the fallback.
signal join_requested(ip: String, port: int)
signal back
var beacon: LanBeacon
var list: VBoxContainer
var status: Label
var ip_edit: LineEdit
var _sig := ""

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(560, 0)
	box.position = Vector2(-280, -250)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title := Label.new()
	title.text = "JOIN GAME"
	title.add_theme_font_size_override("font_size", 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	box.add_child(list)
	var ml := Label.new(); ml.text = "Or enter an address:"
	box.add_child(ml)
	ip_edit = LineEdit.new()
	ip_edit.text = Config.last_ip
	ip_edit.placeholder_text = "Server IP"
	box.add_child(ip_edit)
	var jb := Button.new(); jb.text = "Join this address"
	jb.custom_minimum_size = Vector2(0, 56)
	jb.pressed.connect(func(): Config.last_ip = ip_edit.text; join_requested.emit(ip_edit.text, Config.PORT))
	box.add_child(jb)
	var bb := Button.new(); bb.text = "Back"
	bb.custom_minimum_size = Vector2(0, 56)
	bb.pressed.connect(func(): back.emit())
	box.add_child(bb)
	_refresh()

func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		back.emit()
		get_viewport().set_input_as_handled()

func _process(_d: float) -> void:
	if beacon == null:
		return
	var sig := str(beacon.found.keys())
	for g in beacon.games():
		sig += "%d/%d" % [g.players, g.bots]
	if sig != _sig:
		_refresh()

func _refresh() -> void:
	if beacon:
		_sig = str(beacon.found.keys())
		for g in beacon.games():
			_sig += "%d/%d" % [g.players, g.bots]
	var had_focus := list.get_children().any(func(c): return c.has_focus())
	for c in list.get_children():
		c.queue_free()
	var games: Array = beacon.games() if beacon else []
	status.text = "Searching the LAN..." if games.is_empty() else "%d game(s) found" % games.size()
	for g in games:
		var b := Button.new()
		b.text = "%s   %d players (+%d bots)   %s" % [g.name, g.players, g.bots, g.ip]
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 22)
		var ip: String = g.ip
		var port: int = g.port
		b.pressed.connect(func(): join_requested.emit(ip, port))
		list.add_child(b)
	if had_focus or (not games.is_empty() and get_viewport() and get_viewport().gui_get_focus_owner() == null):
		await get_tree().process_frame
		if list.get_child_count() > 0:
			list.get_child(0).grab_focus()
