extends Node

var out := "/home/bill/Projects/arena-assets/shots/modes"
var world: World

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	var path = "%s/%s.png" % [out, n]
	img.save_png(path)
	print("saved ", path)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	Config.test_mode = false
	Config.bots_enabled = true
	Config.vote_enabled = true
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(24778, 10)
	multiplayer.multiplayer_peer = peer
	world = World.new(); add_child(world)
	world.build()
	world.start_server()
	
	for i in 120: await get_tree().physics_frame
	
	var modes = ["ctf", "koth", "gun_game", "tdm"]
	for m in modes:
		print("Starting mode: ", m)
		world._srv_begin_round(StringName(m), world.level.layout_name)
		for i in 150: await get_tree().physics_frame
		
		var me: Player = world.players.get(1)
		if me == null:
			print("No player 1 for mode ", m)
			continue
		
		await _shot(m + "_play")
		
		if m == "ctf" and me.cam != null:
			var mode_ctf: ModeCtf = world.mode as ModeCtf
			if mode_ctf and mode_ctf.flag.size() >= 2:
				var enemy_flag_pos := mode_ctf.flag[1].pos
				me.cam_arm.global_position = me.global_position + Vector3(0, 1.5, 0)
				me.cam_arm.look_at(enemy_flag_pos + Vector3(0, 1.5, 0))
				await get_tree().physics_frame
				await _shot(m + "_play_enemy_flag")
		
		world._srv_open_vote()
		for i in 60: await get_tree().physics_frame
		await _shot(m + "_vote")
		
		world._srv_close_vote()
		for i in 60: await get_tree().physics_frame
	
	get_tree().quit()
