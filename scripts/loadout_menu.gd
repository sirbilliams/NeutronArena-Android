class_name LoadoutMenu
extends Control
## Standalone loadout picker (no game dependencies except the Balance/Data registries), so it can be moved to a second screen.
## Gamepad: d-pad/stick up-down = row, left-right = change value (or press A on a slot), A on a class = preset, A on CONFIRM = send.
## Emits `confirmed(loadout)`; the owner of the menu decides what to do with it.
signal confirmed(loadout: Dictionary)
signal team_switch_requested

var loadout := Loadout.default_loadout()
var team := 0   ## set by the owner; only changes display names
var _slot_btns := {}      # slot -> Button
var _options := {}        # slot -> Array of ids
var _desc: Label
var _info: Label
var _title: Label
var _confirm: Button
var _class_btns := {}

func _ready() -> void:
	_options[&"primary"] = WeaponData.selectable_ids()
	_options[&"gadget"] = GadgetData.all_ids()
	_options[&"movement"] = MovementData.all_ids()
	_options[&"ultimate"] = UltimateData.all_ids()
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.14, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(620, 0)
	box.position = Vector2(-310, -250)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = Label.new()
	_title.text = "LOADOUT"
	_title.add_theme_font_size_override("font_size", 38)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.modulate = Color(1, 0.85, 0.4)
	box.add_child(_info)
	var cls := HBoxContainer.new()
	cls.add_theme_constant_override("separation", 6)
	box.add_child(cls)
	for cid in Balance.CLASSES:
		var b := Button.new()
		b.text = Balance.CLASSES[cid].name
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_apply_class.bind(cid))
		b.focus_entered.connect(_show_class.bind(cid))
		cls.add_child(b)
		_class_btns[cid] = b
	for s in Balance.SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 46)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(_cycle.bind(s, 1))
		b.gui_input.connect(_slot_input.bind(s))
		b.focus_entered.connect(_show_slot.bind(s))
		box.add_child(b)
		_slot_btns[s] = b
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(0, 50)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_desc)
	_confirm = Button.new()
	_confirm.text = "CONFIRM"
	_confirm.custom_minimum_size = Vector2(0, 52)
	_confirm.add_theme_font_size_override("font_size", 24)
	_confirm.pressed.connect(func(): confirmed.emit(loadout.duplicate()))
	box.add_child(_confirm)
	var sw := Button.new()
	sw.text = "SWITCH TEAM"
	sw.custom_minimum_size = Vector2(0, 46)
	sw.add_theme_font_size_override("font_size", 20)
	sw.pressed.connect(func(): team_switch_requested.emit())
	box.add_child(sw)
	_refresh()

func set_loadout(lo: Dictionary) -> void:
	loadout = Loadout.sanitize(lo)
	if is_node_ready():
		_refresh()

func set_info(text: String) -> void:
	if _info:
		_info.text = text

func focus_first() -> void:
	if _confirm:
		_confirm.grab_focus()

func _name_of(s: StringName, id: StringName) -> String:
	match s:
		&"primary": return WeaponData.get_weapon(id).display_name
		&"gadget": return GadgetData.get_gadget(id).display_name
		&"movement": return MovementData.get_movement(id).display_name
		_: return UltimateData.get_ultimate(id).name_for(team)

func _desc_of(s: StringName, id: StringName) -> String:
	match s:
		&"primary": return WeaponData.get_weapon(id).desc
		&"gadget": return GadgetData.get_gadget(id).desc
		&"movement": return MovementData.get_movement(id).desc
		_: return UltimateData.get_ultimate(id).desc

func _refresh() -> void:
	for s in Balance.SLOTS:
		(_slot_btns[s] as Button).text = "%s:   <  %s  >" % [str(s).capitalize(), _name_of(s, loadout[s])]
	for cid in _class_btns:
		var match_all := true
		for s in Balance.SLOTS:
			if Balance.CLASSES[cid][s] != loadout[s]:
				match_all = false
		(_class_btns[cid] as Button).modulate = Color(0.6, 1.0, 0.6) if match_all else Color.WHITE

func _apply_class(cid: StringName) -> void:
	loadout = Loadout.from_class(cid)
	_refresh()

func _cycle(s: StringName, d: int) -> void:
	var opts: Array = _options[s]
	var i := opts.find(loadout[s])
	loadout[s] = opts[posmod(i + d, opts.size())]
	_refresh()
	_show_slot(s)

func _slot_input(e: InputEvent, s: StringName) -> void:
	if e.is_action_pressed("ui_left"):
		_cycle(s, -1)
		accept_event()
	elif e.is_action_pressed("ui_right"):
		_cycle(s, 1)
		accept_event()

func _show_slot(s: StringName) -> void:
	_desc.text = "%s: %s" % [_name_of(s, loadout[s]), _desc_of(s, loadout[s])]

func _show_class(cid: StringName) -> void:
	var c: Dictionary = Balance.CLASSES[cid]
	_desc.text = "%s preset: %s / %s / %s / %s" % [c.name, _name_of(&"primary", c.primary), _name_of(&"gadget", c.gadget), _name_of(&"movement", c.movement), _name_of(&"ultimate", c.ultimate)]
