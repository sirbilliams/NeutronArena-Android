extends Node
## Every menu in every UI theme: title (real Main menu, switched live), setup, join (faked LAN list), then a listen-server
## match for the HUD, scoreboard, team select and loadout. tools/vrun.sh res://tools/shots_themes.tscn -- --out=DIR [--themes=a,b]
## Writes DIR/<theme>/<screen>.png; tools/contact_sheets.sh builds one sheet per screen.
var out := "/home/bill/Projects/arena-assets/shots/themes"
var themes: Array = []
var title_only := false

func shot(theme: StringName, name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var dir := out.path_join(theme)
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("shot ", theme, "/", name)

func _ready() -> void:
	themes = UiTheme.IDS.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		elif a.begins_with("--themes="): themes = Array(a.substr(9).split(","))
		elif a == "--title-only": title_only = true
	DirAccess.make_dir_recursive_absolute(out)
	# --- title: the real menu, re-themed live through Config.set_theme
	var main = load("res://scripts/main.gd").new()
	add_child(main)
	await get_tree().process_frame
	for id in themes:
		Config.set_theme(id)
		await get_tree().process_frame
		await shot(id, "title")
	main.queue_free()
	await get_tree().process_frame
	if title_only:
		get_tree().quit(); return
	# --- setup screen
	for id in themes:
		Config.set_theme(id)
		var s := SetupScreen.new(true)
		add_child(s)
		await get_tree().process_frame
		s._set_path(0, "/nonexistent/negatron.iso")   # shows the error style
		s._status[1].text = "OK  -  bg.iso  (Boy Genius)"; s._status[1].theme_type_variation = &"Success"
		s._prog_box.visible = true; s._stage_lbl.text = "Converting level5c.ase"; s._stage_bar.value = 0.62; s._all_bar.value = 0.31
		s._import_btn.visible = false
		s._cancel_btn.grab_focus()
		await shot(id, "setup")
		s.queue_free()
		await get_tree().process_frame
	# --- join screen with a faked LAN list
	for id in themes:
		Config.set_theme(id)
		var js := JoinScreen.new()
		js.beacon = LanBeacon.new()
		js.beacon.found = {
			"192.168.1.20:24680": {"ip": "192.168.1.20", "port": 24680, "name": "Carl's Thor", "players": 3, "bots": 7, "max": 10, "map": "street", "seen": 1e12},
			"192.168.1.33:24680": {"ip": "192.168.1.33", "port": 24680, "name": "Sheen-PC", "players": 1, "bots": 9, "max": 10, "map": "street", "seen": 1e12},
		}
		js.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(js)
		await get_tree().process_frame
		await get_tree().process_frame
		await shot(id, "join")
		js.queue_free()
		await get_tree().process_frame
	# --- match: listen server with the player on Jimmy, three Negatron bots ahead, some kills
	Config.test_mode = true
	var world := World.new()
	add_child(world)
	world.build()
	var hud := Hud.new(); hud.world = world; add_child(hud)
	var sb := Scoreboard.new(); sb.world = world; add_child(sb)
	sb.set_process(false)
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(24998, 4)
	multiplayer.multiplayer_peer = peer
	world.start_server()
	await get_tree().create_timer(1.0).timeout
	world.request_team(Config.TEAM_JIMMY)
	for i in 90: await get_tree().physics_frame
	var me: Player = world.players[1]
	var fwd := Vector3(-sin(me.cam_yaw), 0, -cos(me.cam_yaw))
	for k in 3:
		world.c_add_player(100 + k, Config.TEAM_NEGATRON, Transform3D(Basis(), me.global_position + fwd * (5.0 + k * 1.5) + Vector3(-1.5 + k * 1.5, 0.1, 0)))
		world.players[100 + k].model_yaw = me.cam_yaw + PI
	for k in 2:
		world.c_add_player(200 + k, Config.TEAM_JIMMY, Transform3D(Basis(), me.global_position + fwd * 2.0 + Vector3(-3.0 + k * 6.0, 0.1, 0)))
	for i in 60: await get_tree().physics_frame
	world.team_score = [12, 9]
	world.kills = {1: 7, 200: 3, 201: 2, 100: 4, 101: 3, 102: 2}
	world.deaths = {1: 2, 200: 4, 201: 3, 100: 3, 101: 2, 102: 4}
	me.hp = 64
	me.ult_charge = int(me.ultimate.f("cost"))
	me.fuel = 70.0
	for id in themes:
		Config.set_theme(id)
		hud.menu.visible = false; hud.team_menu.visible = false; sb.panel.visible = false
		await get_tree().process_frame
		world.c_hit(100, 1, 24, world.players[100].global_position + Vector3(0, 1.0, 0), false)
		world.c_died(101, 1)
		world.c_died(200, 102)
		await get_tree().create_timer(0.12).timeout
		await shot(id, "hud")
		sb.panel.visible = true; sb.label.text = sb.text()
		await shot(id, "scoreboard")
		sb.panel.visible = false
		hud.team_menu.set_cancelable(true)
		hud.team_menu.set_counts([3, 3]); hud.team_menu.set_info("Switching respawns you on the other side. Score is unchanged.")
		hud.team_menu.visible = true; hud.team_menu.focus_first()
		await shot(id, "team")
		hud.team_menu.visible = false
		hud.menu.team = 0
		hud.menu.set_loadout(Loadout.from_class(&"sky_jockey"))
		hud.menu.set_info("First spawn: pick your loadout, it applies now.")
		hud.menu.visible = true; hud.menu.focus_first()
		await get_tree().process_frame
		(hud.menu._slot_btns[&"primary"] as Button).grab_focus()
		await shot(id, "loadout")
		hud.menu.visible = false
	print("THEME SHOTS DONE")
	get_tree().quit()
