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
var fuel_bar: ProgressBar
var ult_bar: ProgressBar
var menu: LoadoutMenu
var menu_open := false
var first_done := false
var queued_msg := ""
var first_pending := true

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
	if me:
		if not first_done and not Config.test_mode:
			first_done = true
			_set_menu(true)
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
		gear_label.text = "%s | Gadget [Q/LB] %s: %s | Move [Shift/RB] %s | Ult %s: %s%s" % [me.weapon.display_name, me.gadget.display_name, gtxt, me.movement.display_name, me.ultimate.display_name, utxt, ("  SHIELD %d" % int(me.status_val.get("shield", 0)) if me.has_status("shield") else "")]
		kd_label.text = "%s   kills %d  deaths %d" % [Config.TEAM_NAMES[me.team], world.kills.get(me.peer_id, 0), world.deaths.get(me.peer_id, 0)]
		cross.visible = me.alive and not world.match_over
		if world.match_over:
			banner.text = "%s TEAM WINS!" % Config.TEAM_NAMES[world.winner]
		elif not me.alive:
			banner.text = "Respawning..."
		else:
			banner.text = ""

func _on_confirm(lo: Dictionary) -> void:
	world.request_loadout(lo)
	first_pending = false
	queued_msg = "Loadout sent"
	_set_menu(false)

func _set_menu(open: bool) -> void:
	if Config.test_mode or menu_open == open:
		return
	menu_open = open
	menu.visible = open
	var me: Player = world.players.get(multiplayer.get_unique_id())
	if me:
		me.input_blocked = open
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if me:
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
