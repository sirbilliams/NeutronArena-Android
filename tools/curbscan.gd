extends Node3D
## Finds curb-like steps (0.08..0.5 m ground jumps within 5 cm) along lines; prints candidates for the movement test.
func _ready() -> void:
	var lvl := ArenaLevel.new(); add_child(lvl); lvl.load_level()
	await get_tree().physics_frame; await get_tree().physics_frame
	var sp := get_world_3d().direct_space_state
	var s := Config.WORLD_SCALE
	var found := 0
	var zr := -46000.0
	while zr < 14000.0 and found < 40:
		var prev := -99.0
		var x := 0.0
		while x < 18000.0:
			var wx := x * s; var wz := zr * s
			var r := sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(wx, 12, wz), Vector3(wx, -30, wz), 1))
			var y: float = r.position.y if r else -99.0
			if prev > -90 and y > -90 and absf(y - prev) > 0.08 and absf(y - prev) < 0.5:
				print("STEP z_raw=%d x_m=%.2f z_m=%.2f from %.3f to %.3f" % [zr, wx, wz, prev, y])
				found += 1
			prev = y
			x += 8.0   # raw units (5 cm)
		zr += 1500.0
	get_tree().quit()
