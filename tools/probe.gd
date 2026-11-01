extends Node3D
## Ground height grid over the play area (raw coords) to find pits / blocked spots.
func _ready() -> void:
	var lvl := ArenaLevel.new(); add_child(lvl); lvl.load_level()
	await get_tree().physics_frame; await get_tree().physics_frame
	var sp := get_world_3d().direct_space_state
	var pb := lvl._play_bounds()
	var bad := 0
	var z := pb.position.y + 300
	while z < pb.end.y:
		var row := ""
		var x := pb.position.x + 300
		while x < pb.end.x:
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, 12 / Config.WORLD_SCALE * 0 + 12, z) * Vector3(Config.WORLD_SCALE, 1, Config.WORLD_SCALE), Vector3(x * Config.WORLD_SCALE, -30, z * Config.WORLD_SCALE), 1)
			var r := sp.intersect_ray(q)
			var y: float = r.position.y if r else -99.0
			row += "#" if y > 1.0 else ("." if y > -0.5 else ("o" if y > -9 else "?"))
			x += 1200
		print("Z%6d %s" % [z, row])
		z += 1500
	get_tree().quit()
