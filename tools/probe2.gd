extends Node3D
## Horizontal solid-wall scan at 1 m height along x-lines (finds buildings / open cut-throughs between streets).
func _ready() -> void:
	var lvl := ArenaLevel.new(); add_child(lvl); lvl.load_level()
	await get_tree().physics_frame; await get_tree().physics_frame
	var sp := get_world_3d().direct_space_state
	var s := Config.WORLD_SCALE
	for zr in range(-44000, 14000, 3000):
		var x := -1000.0 * s
		var out := ""
		for k in 14:
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, 1.0, zr * s), Vector3(19000 * s, 1.0, zr * s), 1)
			var r := sp.intersect_ray(q)
			if not r: break
			x = r.position.x + 0.3
			out += " %d" % int(r.position.x / s)
		print("L z=", zr, " hits x:", out)
	get_tree().quit()
