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
	add_child(UiBackground.new(true))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = &"MenuPanel"
	card.custom_minimum_size = Vector2(640, 0)
	center.add_child(card)
	var box := VBoxContainer.new()
	card.add_child(box)
	var title := Label.new()
	title.text = "JOIN GAME"
	title.theme_type_variation = &"Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	status = Label.new()
	status.theme_type_variation = &"Info"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)
	var lp := PanelContainer.new()
	lp.theme_type_variation = &"ListPanel"
	lp.custom_minimum_size = Vector2(0, 150)
	box.add_child(lp)
	list = VBoxContainer.new()
	lp.add_child(list)
	var ml := Label.new(); ml.text = "Or enter an address:"
	ml.theme_type_variation = &"Subtitle"
	box.add_child(ml)
	ip_edit = LineEdit.new()
	ip_edit.text = Config.last_ip
	ip_edit.placeholder_text = "Server IP"
	box.add_child(ip_edit)
	var jb := Button.new(); jb.text = "JOIN THIS ADDRESS"
	jb.theme_type_variation = &"PrimaryButton"
	jb.custom_minimum_size = Vector2(0, 56)
	jb.pressed.connect(func(): Config.last_ip = ip_edit.text; join_requested.emit(ip_edit.text, Config.PORT))
	box.add_child(jb)
	var bb := Button.new(); bb.text = "Back"
	bb.theme_type_variation = &"SmallButton"
	bb.custom_minimum_size = Vector2(0, 48)
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
		b.custom_minimum_size = Vector2(0, 60)
		b.theme_type_variation = &"ListButton"
		var ip: String = g.ip
		var port: int = g.port
		b.pressed.connect(func(): join_requested.emit(ip, port))
		list.add_child(b)
	if had_focus or (not games.is_empty() and get_viewport() and get_viewport().gui_get_focus_owner() == null):
		await get_tree().process_frame
		if list.get_child_count() > 0:
			list.get_child(0).grab_focus()
