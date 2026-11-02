extends Node
## Menu + session bootstrap. Also handles CLI: -- --host | --join=IP | --port=N | --test=server|client
var menu: Control
var world: World
var hud: Hud
var status: Label
var port := Config.PORT
var shot_path := ""

func _ready() -> void:
	name = "Main"
	var test := ""
	var join_ip := ""
	var host := false
	for a in OS.get_cmdline_user_args():
		if a == "--host": host = true
		elif a.begins_with("--join="): join_ip = a.substr(7)
		elif a.begins_with("--port="): port = int(a.substr(7))
		elif a.begins_with("--test="): test = a.substr(7)
		elif a.begins_with("--shot="): shot_path = a.substr(7)
		elif a.begins_with("--mode="): Config.start_mode = StringName(a.substr(7))
		elif a.begins_with("--map="): Config.start_map = a.substr(6)
		elif a == "--novote": Config.vote_enabled = false
		elif a == "--bots": Config.bots_enabled = true
		elif a == "--nobots": Config.bots_enabled = false
		elif a.begins_with("--difficulty="): Config.bot_difficulty = a.substr(13)
		elif a.begins_with("--beacon_port="): Config.beacon_port = int(a.substr(14))
	if test != "":
		Config.test_mode = true
		Config.bots_enabled = OS.get_cmdline_user_args().has("--bots")   # tests: no bots unless asked
		var bt := test.begins_with("bot_")
		if bt:
			var tb = load("res://scripts/bot_test.gd").new()
			tb.main = self
			tb.role = test.substr(4)
			add_child(tb)
			return
		if test == "md_flow":
			var tm = load("res://tests/modes_flow.gd").new()
			tm.main = self
			add_child(tm)
			return
		if test.begins_with("ct_"):
			var tc = load("res://tests/controls_test.gd").new()
			tc.main = self
			tc.role = test.substr(3)
			add_child(tc)
			return
		var lo_test := test.begins_with("lo_")
		var t = load("res://scripts/loadout_test.gd" if lo_test else "res://scripts/net_test.gd").new()
		t.main = self
		t.role = test.substr(3) if lo_test else test
		add_child(t)
		return
	if host:
		start_host()
		if shot_path != "":
			await get_tree().create_timer(4.0).timeout
			get_viewport().get_texture().get_image().save_png(shot_path)
			print("saved ", shot_path)
			get_tree().quit()
	elif join_ip != "":
		start_join(join_ip)
	elif not Config.assets_ok():
		_show_setup(false)
	else:
		_build_menu()

## First-launch setup (or "Re-import game files" from the menu): pick the CD images, import on the device.
func _show_setup(can_go_back: bool) -> void:
	if menu:
		menu.queue_free(); menu = null
	var setup := SetupScreen.new(can_go_back)
	add_child(setup)
	setup.finished.connect(func(ok: bool):
		setup.queue_free()
		_build_menu())

func _build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	menu.add_child(UiBackground.new(true))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(row)
	# main card
	var card := PanelContainer.new()
	card.theme_type_variation = &"MenuPanel"
	card.custom_minimum_size = Vector2(440, 0)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(card)
	var box := VBoxContainer.new()
	card.add_child(box)
	var title := Label.new()
	title.text = "NEUTRON ARENA"
	title.theme_type_variation = &"Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Jimmy vs Negatron  -  5v5 bubble gun deathmatch"
	sub.theme_type_variation = &"Subtitle"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(HSeparator.new())
	var quick_btn := Button.new(); quick_btn.text = "QUICK PLAY"
	quick_btn.theme_type_variation = &"PrimaryButton"
	quick_btn.custom_minimum_size = Vector2(0, 60)
	quick_btn.pressed.connect(quick_play)
	box.add_child(quick_btn)
	var host_btn := Button.new(); host_btn.text = "Host game"
	host_btn.pressed.connect(func(): Config.save_settings(); start_host())
	box.add_child(host_btn)
	var join_btn := Button.new(); join_btn.text = "Join game  (LAN list / IP)"
	join_btn.pressed.connect(_show_join)
	box.add_child(join_btn)
	var bots_row := HBoxContainer.new()
	box.add_child(bots_row)
	var bots_cb := CheckBox.new(); bots_cb.text = "Bots: fill to 5v5"
	bots_cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bots_cb.button_pressed = Config.bots_enabled
	bots_cb.toggled.connect(func(on: bool): Config.bots_enabled = on)
	bots_row.add_child(bots_cb)
	var diff := OptionButton.new()
	diff.custom_minimum_size = Vector2(150, 0)
	for d in ["easy", "normal", "hard"]:
		diff.add_item(d.capitalize())
	diff.selected = ["easy", "normal", "hard"].find(Config.bot_difficulty)
	diff.item_selected.connect(func(i: int): Config.bot_difficulty = ["easy", "normal", "hard"][i])
	bots_row.add_child(diff)
	var mode_row := HBoxContainer.new()
	box.add_child(mode_row)
	var mode_l := Label.new(); mode_l.text = "Mode"
	mode_l.theme_type_variation = &"Subtitle"
	mode_l.custom_minimum_size = Vector2(90, 0)
	mode_row.add_child(mode_l)
	var mode_opt := OptionButton.new()
	mode_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mode_ids := []
	for m in Modes.IDS:
		mode_opt.add_item(Modes.name_of(m)); mode_ids.append(m)
	mode_opt.add_item("Random"); mode_ids.append(&"random")
	mode_opt.selected = maxi(mode_ids.find(Config.start_mode), 0)
	mode_opt.item_selected.connect(func(i: int): Config.start_mode = mode_ids[i])
	mode_row.add_child(mode_opt)
	var vote_cb := CheckBox.new(); vote_cb.text = "Map / mode vote between rounds"
	vote_cb.button_pressed = Config.vote_enabled
	vote_cb.toggled.connect(func(on: bool): Config.vote_enabled = on)
	box.add_child(vote_cb)
	box.add_child(_theme_row())
	if Config.gyro_supported():
		box.add_child(_gyro_row())
	var quit := Button.new(); quit.text = "Quit"
	quit.theme_type_variation = &"SmallButton"
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)
	# game files card
	var side := PanelContainer.new()
	side.theme_type_variation = &"SidePanel"
	side.custom_minimum_size = Vector2(380, 0)
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(side)
	var sbox := VBoxContainer.new()
	side.add_child(sbox)
	var sh := Label.new(); sh.text = "GAME FILES"; sh.theme_type_variation = &"Heading"
	sbox.add_child(sh)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.theme_type_variation = &"Info"
	sbox.add_child(status)
	var reimp := Button.new(); reimp.text = "Re-import game files"
	reimp.theme_type_variation = &"SmallButton"
	reimp.pressed.connect(func(): _show_setup(true))
	sbox.add_child(reimp)
	var rl := Label.new(); rl.text = "Neutron vs Negatron / Boy Genius CD images, converted on this device."
	rl.theme_type_variation = &"Dim"; rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sbox.add_child(rl)
	sbox.add_child(HSeparator.new())
	var al := Label.new(); al.text = "Dev: folder with exported glbs (optional, instead of the import):"
	al.theme_type_variation = &"Dim"; al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sbox.add_child(al)
	var ad := LineEdit.new(); ad.text = Config.asset_dir
	ad.placeholder_text = "asset folder"
	ad.text_changed.connect(func(t): Config.asset_dir = t; Config.dev_asset_dir = t; Config.save_settings(); _check_assets())
	sbox.add_child(ad)
	var retry := Button.new(); retry.text = "Check again"
	retry.theme_type_variation = &"SmallButton"
	retry.pressed.connect(func():
		if OS.get_name() == "Android" and not Config.imported_ok():
			Config.request_android_storage()
			Config.find_android_assets()
		ad.text = Config.asset_dir
		_check_assets())
	sbox.add_child(retry)
	_check_assets()
	quick_btn.grab_focus()

## "Theme  <  name  >" row: A / tap = next theme, d-pad left/right = previous/next. Applies live and saves.
var _theme_btn: Button

func _theme_row() -> HBoxContainer:
	var r := HBoxContainer.new()
	var l := Label.new(); l.text = "Theme"
	l.theme_type_variation = &"Subtitle"
	l.custom_minimum_size = Vector2(90, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r.add_child(l)
	_theme_btn = Button.new()
	_theme_btn.theme_type_variation = &"CycleButton"
	_theme_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_theme_btn.pressed.connect(func(): _step_theme(1))
	_theme_btn.gui_input.connect(func(e: InputEvent):
		if e.is_action_pressed("ui_left"):
			_step_theme(-1); _theme_btn.accept_event()
		elif e.is_action_pressed("ui_right"):
			_step_theme(1); _theme_btn.accept_event())
	r.add_child(_theme_btn)
	_update_theme_btn()
	Config.theme_changed.connect(func(_id): _update_theme_btn())
	return r

## Android only: gyro aim on/off, sensitivity, invert Y (Config, saved in settings.cfg).
func _gyro_row() -> VBoxContainer:
	var v := VBoxContainer.new()
	var top := HBoxContainer.new()
	v.add_child(top)
	var cb := CheckBox.new(); cb.text = "Gyro aim"
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb.button_pressed = Config.gyro_enabled
	cb.toggled.connect(func(on: bool): Config.gyro_enabled = on; Config.save_settings())
	top.add_child(cb)
	var inv := CheckBox.new(); inv.text = "Invert Y"
	inv.button_pressed = Config.gyro_invert_y
	inv.toggled.connect(func(on: bool): Config.gyro_invert_y = on; Config.save_settings())
	top.add_child(inv)
	var sr := HBoxContainer.new()
	v.add_child(sr)
	var l := Label.new(); l.text = "Gyro sens"; l.theme_type_variation = &"Subtitle"
	l.custom_minimum_size = Vector2(90, 0)
	sr.add_child(l)
	var sl := HSlider.new()
	sl.min_value = 0.2; sl.max_value = 3.0; sl.step = 0.1; sl.value = Config.gyro_sens
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(0, 32)
	sl.value_changed.connect(func(x: float): Config.gyro_sens = x; Config.save_settings())
	sr.add_child(sl)
	return v

func _step_theme(d: int) -> void:
	var i := UiTheme.IDS.find(Config.theme_id)
	Config.set_theme(UiTheme.IDS[posmod(i + d, UiTheme.IDS.size())])
	_update_theme_btn()

func _update_theme_btn() -> void:
	if _theme_btn:
		_theme_btn.text = "<   %s   >" % UiTheme.display_name(Config.theme_id)

func _check_assets() -> void:
	if status:
		if Config.assets_ok():
			status.text = "Game files OK (both discs imported)." if Config.has_n1() else "Game files OK. Boy Genius ISO not imported: N1 gadgets use simple placeholder models (use Re-import to add it)."
			status.theme_type_variation = &"Success" if Config.has_n1() else &"Info"
		else:
			status.text = "Game files not found. Use \"Re-import game files\" to pick your CD images."
			status.theme_type_variation = &"Danger"

func _enter_game() -> bool:
	if not Config.assets_ok():
		if status: status.text = "Assets not found: set the asset folder first."
		return false
	Config.save_settings()
	if menu:
		menu.queue_free(); menu = null
	world = World.new()
	add_child(world)
	if not world.build():
		push_error("level failed to load")
		return false
	hud = Hud.new(); hud.world = world; add_child(hud)
	var sb := Scoreboard.new(); sb.world = world; add_child(sb)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if DisplayServer.get_name() != "headless" and not Config.test_mode else Input.MOUSE_MODE_VISIBLE
	return true

func _show_join() -> void:
	if menu:
		menu.visible = false
	beacon = LanBeacon.new()
	add_child(beacon)
	beacon.start_listen()
	var js := JoinScreen.new()
	js.beacon = beacon
	js.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(js)
	var close := func():
		js.queue_free(); beacon.queue_free(); beacon = null
		if menu: menu.visible = true
	js.back.connect(close)
	js.join_requested.connect(func(ip: String, prt: int):
		js.queue_free(); beacon.queue_free(); beacon = null
		port = prt
		Config.save_settings()
		start_join(ip))

var beacon: LanBeacon

## Quick Play: join a LAN game if one answers within ~2 s, else host with bots. Auto team + last-used loadout.
func quick_play() -> void:
	if is_instance_valid(status): status.text = "Looking for a LAN game..."
	var lb := LanBeacon.new()
	add_child(lb)
	lb.start_listen()
	var t := 0.0
	while t < 2.0 and lb.games().is_empty():
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	var games := lb.games()
	lb.queue_free()
	var ok := false
	if not games.is_empty():
		port = games[0].port
		ok = start_join(games[0].ip)
		if ok:
			await multiplayer.connected_to_server
	else:
		Config.bots_enabled = true
		ok = start_host()
	if not ok:
		if is_instance_valid(status): status.text = "Quick Play failed."
		return
	hud.ever_joined = true      # no team menu: auto team
	hud.first_done = true       # no loadout menu: last-used loadout
	hud.first_pending = false
	world.request_team(-1)
	while not world.players.has(multiplayer.get_unique_id()):
		await get_tree().create_timer(0.1).timeout
	if not Config.last_loadout.is_empty():
		world.request_loadout(Config.last_loadout)

func start_host() -> bool:
	if not _enter_game(): return false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, Config.MAX_PLAYERS)
	if err != OK:
		push_error("host failed: %d" % err)
		return false
	multiplayer.multiplayer_peer = peer
	world.start_server()
	beacon = LanBeacon.new()
	add_child(beacon)
	beacon.start_host(func():
		var humans := 0
		for i in world.info:
			if i > 0: humans += 1
		return {"name": LanBeacon.host_name(), "players": humans, "bots": world.info.size() - humans, "max": Config.MAX_PLAYERS, "map": world.level.layout_name, "port": port})
	print("HOSTING on port ", port, " bots=", Config.bots_enabled, " ", Config.bot_difficulty)
	return true

func start_join(ip: String) -> bool:
	if not _enter_game(): return false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		push_error("join failed: %d" % err)
		return false
	multiplayer.multiplayer_peer = peer
	multiplayer.server_disconnected.connect(func():
		print("server disconnected")
		if not Config.test_mode:
			get_tree().quit())
	return true

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif e is InputEventMouseButton and e.pressed and world:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
