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
	var hud := Hud.new(); hud.world = world; add_child(hud)
	var sb := Scoreboard.new(); sb.world = world; add_child(sb)
	world.start_server()
	
	for i in 120: await get_tree().physics_frame
	world.request_team(Config.TEAM_JIMMY)
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
		
		world._srv_open_vote()
		for i in 60: await get_tree().physics_frame
		await _shot(m + "_vote")
		
		world._srv_close_vote()
		for i in 60: await get_tree().physics_frame
	
	get_tree().quit()
