class_name TeamMenu
extends Control
## Team picker (Jimmy / Negatron / Auto-balance), styled like LoadoutMenu. Gamepad: d-pad up/down + A, B = cancel (switch mode only).
signal chosen(team: int)   ## 0 Jimmy, 1 Negatron, -1 auto
signal cancelled
var can_cancel := false
var _title: Label
var _info: Label
var _btns: Array[Button] = []
var _cancel: Button

func _ready() -> void:
	add_child(UiBackground.new(false))   # themed overlay, follows live theme changes
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(560, 0)
	box.position = Vector2(-280, -230)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	_title = Label.new()
	_title.text = "CHOOSE YOUR TEAM"
	_title.theme_type_variation = &"Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.theme_type_variation = &"Info"
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(0, 30)
	box.add_child(_info)
	for t in [Config.TEAM_JIMMY, Config.TEAM_NEGATRON, -1]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 84)
		b.theme_type_variation = [&"TeamJimmyButton", &"TeamNegatronButton", &"PrimaryButton"][t if t >= 0 else 2]
		b.pressed.connect(func(): chosen.emit(t))
		box.add_child(b)
		_btns.append(b)
	_cancel = Button.new()
	_cancel.text = "BACK"
	_cancel.custom_minimum_size = Vector2(0, 52)
	_cancel.theme_type_variation = &"SmallButton"
	_cancel.pressed.connect(func(): cancelled.emit())
	box.add_child(_cancel)
	set_counts([0, 0])
	_apply_cancel()

func set_counts(c: Array) -> void:
	if _btns.is_empty():
		return
	_btns[0].text = "JIMMY   (%d/%d)" % [c[0], World.TEAM_CAP]
	_btns[1].text = "NEGATRON   (%d/%d)" % [c[1], World.TEAM_CAP]
	_btns[2].text = "AUTO-BALANCE"

func set_info(text: String) -> void:
	if _info:
		_info.text = text

func set_cancelable(v: bool) -> void:
	can_cancel = v
	if is_node_ready():
		_apply_cancel()

func _apply_cancel() -> void:
	_cancel.visible = can_cancel
	_title.text = "SWITCH TEAM" if can_cancel else "CHOOSE YOUR TEAM"

func focus_first() -> void:
	if not _btns.is_empty():
		_btns[2].grab_focus()

func _unhandled_input(e: InputEvent) -> void:
	if visible and can_cancel and e.is_action_pressed("ui_cancel"):
		cancelled.emit()
		get_viewport().set_input_as_handled()
