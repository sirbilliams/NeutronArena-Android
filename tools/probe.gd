extends Node3D
func _ready() -> void:
	var lvl := ArenaLevel.new(); add_child(lvl); lvl.load_level()
	await get_tree().physics_frame; await get_tree().physics_frame
	var sp := get_world_3d().direct_space_state
	for z in range(-330, 140, 20):
		var row := ""
		for x in [5, 20, 40, 95, 130]:
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, 12, z), Vector3(x, -30, z), 1)
			var r := sp.intersect_ray(q)
			row += "%6s " % (("%.1f" % r.position.y) if r else "none")
		print("z=", z, " ", row)
	get_tree().quit()
