class_name CharacterSelect
extends Control
## Character select: a grid of the team's roster, each card a live 3D preview (SubViewport, slow spin, idle animation).
## Plain Controls only (the global theme styles them). Gamepad: d-pad / stick moves, A picks a card (focus jumps to SELECT), A on SELECT confirms,
## B = back. Mouse / touch: tap a card, then SELECT. Characters whose art is not imported show LOCKED with a hint.
signal chosen(id: StringName)
signal cancelled
const CARD := Vector2(170, 250)
const SPIN := 0.7   # rad/s

var team := 0
var current: StringName = &"jimmy"
var _title: Label
var _name: Label
var _blurb: Label
var _hint: Label
var _grid: GridContainer
var _cards := {}       # id -> Button
var _spin: Array = []  # [{model, base_yaw}]
var _select: Button
var _back: Button
var _group := ButtonGroup.new()

func _ready() -> void:
	var back := PanelContainer.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(back)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_grid)
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_name)
	_blurb = Label.new()
	_blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(CARD.x * 5, 0)
	box.add_child(_blurb)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_back = Button.new()
	_back.text = "BACK"
	_back.custom_minimum_size = Vector2(160, 48)
	_back.pressed.connect(func(): cancelled.emit())
	row.add_child(_back)
	_select = Button.new()
	_select.text = "SELECT"
	_select.custom_minimum_size = Vector2(220, 48)
	_select.pressed.connect(_confirm)
	row.add_child(_select)
	visibility_changed.connect(_on_visibility)
	_rebuild()

## Shows the roster of `t`; `cur` (a character of that team) is preselected.
func open(t: int, cur: StringName) -> void:
	team = t
	current = Characters.sanitize(cur, t)
	if not Characters.available(current):
		current = Characters.default_for_team(t)
	if is_node_ready():
		_rebuild()
	visible = true
	focus_current()

func focus_current() -> void:
	if _cards.has(current):
		(_cards[current] as Button).grab_focus()
	elif _select:
		_select.grab_focus()

func _on_visibility() -> void:
	for c in _cards.values():
		var sv := (c as Button).get_meta("viewport", null) as SubViewport
		if sv:
			sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_cards.clear()
	_spin.clear()
	_title.text = "%s TEAM - CHOOSE YOUR CHARACTER" % Config.TEAM_NAMES[team]
	for id in Characters.ids_for_team(team):
		var b := _make_card(id)
		_grid.add_child(b)
		_cards[id] = b
	_show(current)

func _make_card(id: StringName) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = _group
	b.custom_minimum_size = CARD
	b.focus_entered.connect(_show.bind(id))
	b.pressed.connect(_pick.bind(id))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var unlocked := Characters.available(id)
	if unlocked:
		var cont := SubViewportContainer.new()
		cont.stretch = true
		cont.custom_minimum_size = Vector2(CARD.x, CARD.y - 34)
		cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sv := SubViewport.new()
		sv.own_world_3d = true
		sv.transparent_bg = true
		sv.msaa_3d = Viewport.MSAA_2X
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sv.size = Vector2i(CARD.x, CARD.y - 34)
		cont.add_child(sv)
		v.add_child(cont)
		_fill_preview(sv, id)
		b.set_meta("viewport", sv)
	else:
		var l := Label.new()
		l.text = "LOCKED"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(CARD.x, CARD.y - 34)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	var nl := Label.new()
	nl.text = Characters.display_name(id)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nl)
	b.button_pressed = id == current
	return b

func _fill_preview(sv: SubViewport, id: StringName) -> void:
	var d := CharModel.build_display(id)
	if d.is_empty():
		return
	var m: Node3D = d.model
	var k: float = d.k
	m.scale = Vector3.ONE * Config.WORLD_SCALE * k
	m.position.y = FootTable.lift(d.idle) * k
	m.rotation.y = Player.MODEL_YAW - 0.5
	sv.add_child(m)
	_spin.append({"model": m, "yaw": m.rotation.y})
	var ap := m.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap and d.idle != "" and ap.has_animation(d.idle):
		ap.play(d.idle)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.75)
	var we := WorldEnvironment.new(); we.environment = env
	sv.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 35, 0)
	sv.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 33
	sv.add_child(cam)
	cam.position = Vector3(0, 0.78, 3.4)
	cam.look_at_from_position(cam.position, Vector3(0, 0.72, 0))

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	for s in _spin:
		var m: Node3D = s.model
		if is_instance_valid(m):
			m.rotation.y += delta * SPIN

func _show(id: StringName) -> void:
	_name.text = Characters.display_name(id)
	_blurb.text = Characters.ROSTER[id].blurb
	_hint.text = "" if Characters.available(id) else Characters.lock_hint(id)

func _pick(id: StringName) -> void:
	if not Characters.available(id):
		_hint.text = Characters.lock_hint(id)
		if _cards.has(current):
			(_cards[current] as Button).button_pressed = true
		return
	current = id
	_show(id)
	_select.grab_focus()

func _confirm() -> void:
	if Characters.available(current):
		chosen.emit(current)

func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		cancelled.emit()
		get_viewport().set_input_as_handled()
