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
	if test != "":
		Config.test_mode = true
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
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(420, 0)
	box.position = Vector2(-210, -200)
	box.add_theme_constant_override("separation", 12)
	menu.add_child(box)
	var title := Label.new()
	title.text = "NEUTRON ARENA"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Jimmy vs Negatron - 5v5 bubble gun deathmatch"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var host_btn := Button.new(); host_btn.text = "Host game"
	host_btn.pressed.connect(start_host)
	box.add_child(host_btn)
	var ip := LineEdit.new(); ip.text = Config.last_ip; ip.placeholder_text = "Server IP"
	box.add_child(ip)
	var join_btn := Button.new(); join_btn.text = "Join game"
	join_btn.pressed.connect(func(): Config.last_ip = ip.text; start_join(ip.text))
	box.add_child(join_btn)
	var reimp := Button.new(); reimp.text = "Re-import game files (Neutron / Boy Genius ISO)"
	reimp.pressed.connect(func(): _show_setup(true))
	box.add_child(reimp)
	var al := Label.new(); al.text = "Dev: asset folder with exported glbs (optional, instead of the import):"
	box.add_child(al)
	var ad := LineEdit.new(); ad.text = Config.asset_dir
	ad.text_changed.connect(func(t): Config.asset_dir = t; Config.dev_asset_dir = t; Config.save_settings(); _check_assets())
	box.add_child(ad)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	var retry := Button.new(); retry.text = "Check again"
	retry.pressed.connect(func():
		if OS.get_name() == "Android" and not Config.imported_ok():
			Config.request_android_storage()
			Config.find_android_assets()
		ad.text = Config.asset_dir
		_check_assets())
	box.add_child(retry)
	var quit := Button.new(); quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)
	_check_assets()
	host_btn.grab_focus()

func _check_assets() -> void:
	if status:
		if Config.assets_ok():
			status.text = "" if Config.has_n1() else "Game files OK. Boy Genius ISO not imported: N1 gadgets use simple placeholder models (use Re-import to add it)."
		else:
			status.text = "Game files not found. Use \"Re-import game files\" to pick your CD images."

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
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if DisplayServer.get_name() != "headless" and not Config.test_mode else Input.MOUSE_MODE_VISIBLE
	return true

func start_host() -> bool:
	if not _enter_game(): return false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, Config.MAX_PLAYERS)
	if err != OK:
		push_error("host failed: %d" % err)
		return false
	multiplayer.multiplayer_peer = peer
	world.start_server()
	print("HOSTING on port ", port)
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
