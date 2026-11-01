class_name Hud
extends CanvasLayer
## Score / HP / respawn / winner HUD.
var world: World
var score_label: Label
var hp_bar: ProgressBar
var info_label: Label
var banner: Label
var cross: Label
var kd_label: Label
var gear_label: Label
var feedback: Feedback
var fuel_bar: ProgressBar
var ult_bar: ProgressBar
var menu: LoadoutMenu
var menu_open := false
var team_menu: TeamMenu
var team_open := false
var ever_joined := false
var first_done := false
var queued_msg := ""
var first_pending := true
var char_select: CharacterSelect
var char_open := false
var _last_team := -1

func _ready() -> void:
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	score_label.position = Vector2(-180, 10)
	add_child(score_label)
	hp_bar = ProgressBar.new()
	hp_bar.max_value = Config.MAX_HP
	hp_bar.custom_minimum_size = Vector2(260, 22)
	hp_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hp_bar.position = Vector2(30, -50)
	add_child(hp_bar)
	kd_label = Label.new()
	kd_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	kd_label.position = Vector2(30, -80)
	add_child(kd_label)
	cross = Label.new()
	cross.text = "+"
	cross.add_theme_font_size_override("font_size", 28)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(8, -18)
	add_child(cross)
	banner = Label.new()
	banner.add_theme_font_size_override("font_size", 44)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.position = Vector2(-250, -140)
	add_child(banner)
	gear_label = Label.new()
	gear_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	gear_label.position = Vector2(30, -140)
	add_child(gear_label)
	fuel_bar = ProgressBar.new()
	fuel_bar.custom_minimum_size = Vector2(260, 12)
	fuel_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	fuel_bar.position = Vector2(30, -26)
	fuel_bar.show_percentage = false
	fuel_bar.modulate = Color(1, 0.7, 0.2)
	add_child(fuel_bar)
	ult_bar = ProgressBar.new()
	ult_bar.custom_minimum_size = Vector2(260, 12)
	ult_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ult_bar.position = Vector2(30, -110)
	ult_bar.show_percentage = false
	add_child(ult_bar)
	menu = (load("res://scenes/loadout_menu.tscn") as PackedScene).instantiate() as LoadoutMenu
	menu.visible = false
	menu.confirmed.connect(_on_confirm)
	var ml := CanvasLayer.new(); ml.layer = 10
	add_child(ml)
	ml.add_child(menu)
	menu.team_switch_requested.connect(_open_team_menu.bind(true))
	char_select = CharacterSelect.new()
	char_select.set_anchors_preset(Control.PRESET_FULL_RECT)
	char_select.visible = false
	char_select.chosen.connect(_on_char_chosen)
	char_select.cancelled.connect(_close_char_select)
	menu.character_requested.connect(_open_char_select)
	team_menu = TeamMenu.new()
	team_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	team_menu.visible = false
	team_menu.chosen.connect(_on_team_chosen)
	team_menu.cancelled.connect(func(): _close_team_menu())
	ml.add_child(team_menu)
	world.team_refused.connect(func(msg: String): team_menu.set_info(msg))
	feedback = Feedback.new()
	feedback.world = world
	add_child(feedback)
	info_label = Label.new()
	info_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	info_label.position = Vector2(10, 10)
	add_child(info_label)

func _process(_d: float) -> void:
	if world == null or not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	score_label.text = "JIMMY %d  -  %d NEGATRON   (first to %d)" % [world.team_score[0], world.team_score[1], Config.WIN_SCORE]
	var me: Player = world.players.get(multiplayer.get_unique_id())
	info_label.text = "players: %d   %s" % [world.players.size(), "host" if multiplayer.is_server() else "client"]
	if team_open:
		team_menu.set_counts(_counts())
	if me:
		ever_joined = true
	if me == null and not ever_joined and not team_open and not Config.test_mode:
		_open_team_menu(false)
	if me and team_open and not team_menu.can_cancel:
		_close_team_menu()
	if me:
		if not first_done and not Config.test_mode:
			first_done = true
			_set_menu(true)
			_open_char_select()   # character select right after the team choice, then the loadout menu
		elif _last_team != -1 and me.team != _last_team and not Config.test_mode:
			_set_menu(true)
			_open_char_select()   # switched teams: pick a character of the new side
		_last_team = me.team
		if not me.alive and not menu_open and queued_msg == "" and not world.match_over:
			_set_menu(true)
		if me.alive and queued_msg != "" and not menu_open:
			queued_msg = ""
		hp_bar.max_value = me.max_hp
		hp_bar.value = me.hp
		var cost := int(me.ultimate.f("cost"))
		ult_bar.max_value = cost
		ult_bar.value = me.ult_charge
		ult_bar.modulate = Color(1, 0.9, 0.2) if me.ult_charge >= cost else Color(0.5, 0.7, 1.0)
		var fmax := me.movement.f("fuel")
		fuel_bar.visible = fmax > 0.0
		fuel_bar.max_value = maxf(fmax, 1.0)
		fuel_bar.value = me.fuel
		var gtxt := "READY" if me.gadget_cd <= 0.0 else "%.1fs" % me.gadget_cd
		var utxt := "ACTIVE %.1fs" % me.status.get("ult", 0.0) if me.has_status("ult") else ("READY (F / LB+RB)" if me.ult_charge >= cost else "%d%%" % int(100.0 * me.ult_charge / cost))
		gear_label.text = "%s | Gadget [Q/LB] %s: %s | Move [Shift/RB] %s | Ult %s: %s%s" % [me.weapon.display_name, me.gadget.display_name, gtxt, me.movement.display_name, me.ultimate.name_for(me.team), utxt, ("  SHIELD %d" % int(me.status_val.get("shield", 0)) if me.has_status("shield") else "")]
		kd_label.text = "%s   kills %d  deaths %d" % [Config.TEAM_NAMES[me.team], world.kills.get(me.peer_id, 0), world.deaths.get(me.peer_id, 0)]
		cross.visible = me.alive and not world.match_over
		if world.match_over:
			banner.text = "%s TEAM WINS!" % Config.TEAM_NAMES[world.winner]
		elif not me.alive:
			banner.text = "Respawning..."
		else:
			banner.text = ""

func _counts() -> Array:
	var c := [0, 0]
	for p in world.players.values():
		c[p.team] += 1
	return c

func _open_team_menu(switching: bool) -> void:
	if Config.test_mode:
		return
	team_open = true
	team_menu.set_cancelable(switching)
	team_menu.set_info("Pick a side, or auto-balance." if not switching else "Switching respawns you on the other side. Score is unchanged.")
	team_menu.set_counts(_counts())
	team_menu.visible = true
	menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	team_menu.focus_first()

func _close_team_menu() -> void:
	team_open = false
	team_menu.visible = false
	if menu_open:
		menu.visible = true
		menu.focus_first()
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _open_char_select() -> void:
	var me: Player = world.players.get(multiplayer.get_unique_id())
	if me == null or Config.test_mode:
		return
	char_open = true
	menu.visible = false
	char_select.open(me.team, menu.loadout.get("char", &""))

func _close_char_select() -> void:
	char_open = false
	char_select.visible = false
	if menu_open:
		menu.visible = true
		menu.focus_first()

func _on_char_chosen(id: StringName) -> void:
	menu.set_character(id)
	_close_char_select()

func _on_team_chosen(t: int) -> void:
	world.request_team(t)
	if team_menu.can_cancel:
		_close_team_menu()
		_set_menu(false)

func _on_confirm(lo: Dictionary) -> void:
	Config.last_loadout = Loadout.to_wire(lo)
	Config.save_settings()
	world.request_loadout(lo)
	first_pending = false
	queued_msg = "Loadout sent"
	_set_menu(false)

func _set_menu(open: bool) -> void:
	if Config.test_mode or menu_open == open:
		return
	menu_open = open
	menu.visible = open
	if not open:
		char_open = false
		char_select.visible = false
	var me: Player = world.players.get(multiplayer.get_unique_id())
	if me:
		me.input_blocked = open
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if me:
			menu.team = me.team
			menu.set_loadout(me.pending_loadout if not me.pending_loadout.is_empty() else me.loadout)
		menu.set_info("First spawn: pick your loadout, it applies now." if first_pending else ("Dead: your choice applies when you respawn." if me and not me.alive else "Applies on your next respawn. [L] / Back closes."))
		menu.focus_first()
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("loadout_menu") and world and not Config.test_mode:
		var me: Player = world.players.get(multiplayer.get_unique_id())
		if me and me.alive:
			_set_menu(not menu_open)
