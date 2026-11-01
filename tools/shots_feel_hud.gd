extends Node
## Feedback screenshots with the real World + Hud (listen server, test_mode): hit marker + damage number, kill feed, low-HP vignette, damage indicator, jetpack flames, muzzle flash, death pop.
## tools/vrun.sh res://tools/shots_feel_hud.tscn -- --out=DIR
var out := "/home/bill/Projects/arena-assets/shots/feel"
var world: World
var hud: Hud

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)

func _ready() -> void:
	name = "Main"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	Config.test_mode = true
	world = World.new()
	add_child(world)
	world.build()
	hud = Hud.new(); hud.world = world; add_child(hud)
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(24999, 4)
	multiplayer.multiplayer_peer = peer
	world.start_server()
	await get_tree().create_timer(1.0).timeout
	world.request_team(Config.TEAM_JIMMY)
	for i in 120: await get_tree().physics_frame
	var me: Player = world.players[1]
	me.cam_yaw = me.cam_yaw
	# two enemies ahead of the camera
	var fwd := Vector3(-sin(me.cam_yaw), 0, -cos(me.cam_yaw))
	for k in 3:
		world.c_add_player(100 + k, Config.TEAM_NEGATRON, Transform3D(Basis(), me.global_position + fwd * (5.0 + k * 1.5) + Vector3(-1.5 + k * 1.5, 0.1, 0)))
		world.players[100 + k].model_yaw = me.cam_yaw + PI
	for i in 90: await get_tree().physics_frame
	# muzzle flash
	var en: Player = world.players[100]
	me.shoot_pose = 0.4
	me.muzzle_flash(&"bubble_gun")
	await shot("muzzle_flash")
	# hit marker + damage number
	world.c_hit(100, 1, 20, en.global_position + Vector3(0, 1.0, 0), false)
	await get_tree().create_timer(0.1).timeout
	await shot("hit_marker_damage")
	# kill: red marker + feed
	await get_tree().create_timer(0.5).timeout
	world.c_hit(101, 1, 70, world.players[101].global_position + Vector3(0, 1.0, 0), true)
	world.c_died(101, 1)
	await get_tree().create_timer(0.08).timeout
	await shot("kill_pop_marker_feed")
	await get_tree().create_timer(0.2).timeout
	await shot("death_pop_mid")
	world.c_died(102, 1)
	world.c_died(100, 1)
	await get_tree().create_timer(1.5).timeout
	await shot("kill_feed")
	# low HP vignette + damage indicator (hit from the right)
	me.hp = 15
	var shooter: Player = world.players[102]
	shooter.set_alive_at(Transform3D(Basis(), me.global_position + Vector3(cos(me.cam_yaw), 0, -sin(me.cam_yaw)) * 6.0))
	world.c_hit(1, 102, 20, me.global_position + Vector3(0, 1, 0), false)
	await get_tree().create_timer(0.35).timeout
	await shot("low_hp_vignette_indicator")
	me.hp = me.max_hp
	# jetpack flames
	var lo := Loadout.default_loadout(); lo["movement"] = &"jetpack"
	world.c_loadout(1, Loadout.to_wire(lo), me.max_hp)
	me.global_position.y += 2.0
	me.mv_flags = 1
	me.velocity.y = 0
	for i in 40: await get_tree().physics_frame
	me.cam_yaw += 2.6
	await get_tree().create_timer(0.3).timeout
	await shot("jetpack_flames_behind")
	get_tree().quit()
