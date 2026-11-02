class_name VoteScreen
extends Control
## Pre-round vote: one big button per mode (and per map when there is more than one). Gamepad: d-pad + A, touch: tap.
## Themed through UiTheme variations only. `voted(mode_i, map_i)` goes to World.request_vote; `skipped` is host-only.
signal voted(mode_i: int, map_i: int)
signal skipped
var mode_ids: Array = []
var map_names: Array = []
var my_mode := -1
var my_map := -1
var ends_at := 0.0
var is_host := false
var _timer: Label
var _mode_btns: Array[Button] = []
var _map_btns: Array[Button] = []
var _skip: Button
var _box: VBoxContainer

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiBackground.new(false))
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER)
	_box.custom_minimum_size = Vector2(620, 0)
	_box.position = Vector2(-310, -250)
	_box.add_theme_constant_override("separation", 10)
	add_child(_box)

func open(modes: Array, maps: Array, secs: float, host: bool) -> void:
	mode_ids = modes
	map_names = maps
	my_mode = -1
	my_map = -1
	is_host = host
	ends_at = Time.get_ticks_msec() / 1000.0 + secs
	for c in _box.get_children():
		c.queue_free()
	_mode_btns.clear(); _map_btns.clear()
	var title := Label.new(); title.text = "NEXT ROUND"; title.theme_type_variation = &"Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	_timer = Label.new(); _timer.theme_type_variation = &"Info"
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_timer)
	var h1 := Label.new(); h1.text = "MODE"; h1.theme_type_variation = &"Heading"
	_box.add_child(h1)
	for i in modes.size():
		var b := Button.new()
		b.theme_type_variation = &"ListButton"
		b.custom_minimum_size = Vector2(0, 64)
		b.tooltip_text = Modes.desc_of(StringName(modes[i]))
		b.pressed.connect(func(): _pick_mode(i))
		_box.add_child(b)
		_mode_btns.append(b)
	if maps.size() > 1:
		var h2 := Label.new(); h2.text = "MAP"; h2.theme_type_variation = &"Heading"
		_box.add_child(h2)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_box.add_child(row)
		for i in maps.size():
			var b := Button.new()
			b.theme_type_variation = &"ListButton"
			b.custom_minimum_size = Vector2(0, 64)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func(): _pick_map(i))
			row.add_child(b)
			_map_btns.append(b)
	_skip = Button.new()
	_skip.theme_type_variation = &"SmallButton"
	_skip.custom_minimum_size = Vector2(0, 52)
	_skip.text = "SKIP VOTE (random / leading)"
	_skip.visible = host
	_skip.pressed.connect(func(): skipped.emit())
	_box.add_child(_skip)
	set_counts([], [])
	visible = true
	if not _mode_btns.is_empty():
		_mode_btns[0].grab_focus()

func close() -> void:
	visible = false

static func map_title(n: String) -> String:
	return {"museum": "Museum Run (long)", "compact": "Candy Bar Block (short)"}.get(n, n.capitalize())

func set_counts(mc: Array, pc: Array) -> void:
	for i in _mode_btns.size():
		var n: int = mc[i] if i < mc.size() else 0
		_mode_btns[i].text = "%s%s   [%d]\n%s" % ["> " if i == my_mode else "", Modes.name_of(StringName(mode_ids[i])), n, Modes.desc_of(StringName(mode_ids[i]))]
		_mode_btns[i].add_theme_font_size_override("font_size", 17)
	for i in _map_btns.size():
		var n: int = pc[i] if i < pc.size() else 0
		_map_btns[i].text = "%s%s   [%d]" % ["> " if i == my_map else "", map_title(map_names[i]), n]

func _pick_mode(i: int) -> void:
	my_mode = i
	voted.emit(my_mode, my_map)

func _pick_map(i: int) -> void:
	my_map = i
	voted.emit(my_mode, my_map)

func _process(_d: float) -> void:
	if visible and _timer:
		_timer.text = "Vote: %d s   (tap / A to choose, ties are random)" % maxi(0, ceili(ends_at - Time.get_ticks_msec() / 1000.0))
