extends Node
## 1 human + 9 bots match screenshots. tools/vrun.sh res://tools/shots_bots.tscn -- --out=DIR
var out := "/home/bill/Projects/arena-assets/shots/bots"
var world: World

func _snap(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	Config.test_mode = true
	Config.bots_enabled = true
	Config.bot_difficulty = "hard"
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(24777, 10)
	multiplayer.multiplayer_peer = peer
	world = World.new(); add_child(world)
	world.build()
	world.start_server()
	var cam := Camera3D.new(); cam.far = 600; add_child(cam)
	await get_tree().create_timer(6.0).timeout
	cam.current = true
	var me: Player = world.players[1]
	cam.global_position = me.global_position + Vector3(0, 4, 9)
	cam.look_at(me.global_position + Vector3(0, 1.2, -6))
	await _snap("spawn_base")
	var shot := 0
	var t := 0.0
	while t < 100.0 and shot < 5:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
		# pick a bot that sees a target
		var best: BotBrain = null
		for b in world.bot_mgr.brains.values():
			if b.target_vis and b.player and b.player.alive and (best == null or b.fire_want):
				best = b
		if best and t > 15.0:
			var bp := best.player.global_position
			var f := Vector3(-sin(best.yaw), 0, -cos(best.yaw))
			cam.global_position = bp - f * 4.5 + Vector3(0, 2.2, 0) + f.cross(Vector3.UP) * 1.2
			cam.look_at(bp + f * 8.0 + Vector3(0, 1.2, 0))
			await _snap("combat_%d" % shot)
			shot += 1
			await get_tree().create_timer(5.0).timeout
			t += 5.0
		elif int(t) % 25 == 0 and t > 10.0 and shot == 0:
			var any: Player = world.players[world.bot_mgr.brains.keys()[3]]
			cam.global_position = any.global_position + Vector3(0, 12, 14)
			cam.look_at(any.global_position)
			await _snap("route_%d" % int(t))
	print("score ", world.team_score, " kills ", world.kills)
	get_tree().quit()
