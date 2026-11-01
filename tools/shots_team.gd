extends Node3D
## Team select + street (cover removed) screenshots. tools/vrun.sh res://tools/shots_team.tscn -- --out=DIR
var out := "/home/bill/Projects/arena-assets/shots/team"

func _snap(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var world := World.new(); add_child(world)
	print("build ", world.build())
	var cam := Camera3D.new(); cam.far = 2000; add_child(cam); cam.current = true
	for i in 10: await get_tree().physics_frame
	var lv := world.level
	var c := lv.raw_to_world(ArenaLevel.CANDY_CENTER)
	# street runs away from the Candy Bar: look along the route at eye height, then from above
	var sp := lv.spawn_point(0, 0, 1)
	var o := sp.origin
	cam.global_position = o + Vector3(0, 1.7, 0)
	cam.look_at(o + Vector3(0, 1.4, -1) * 10.0 + Vector3(0, 0, 0))
	for k in 6: await get_tree().process_frame
	await _snap("street_a")
	cam.global_position = c + Vector3(-14, 2.5, 14)
	cam.look_at(c + Vector3(10, 1, -14))
	await _snap("street_b")
	cam.global_position = c + Vector3(0, 40, 30)
	cam.look_at(c + Vector3(0, 0, -30))
	await _snap("street_c_top")
	var layer := CanvasLayer.new(); add_child(layer)
	var tm := TeamMenu.new(); tm.set_anchors_preset(Control.PRESET_FULL_RECT); layer.add_child(tm)
	await get_tree().process_frame
	tm.set_counts([3, 2]); tm.set_info("JIMMY is full - you joined NEGATRON.")
	tm.focus_first()
	await _snap("team_select")
	tm.set_cancelable(true)
	tm.set_info("Switching respawns you on the other side. Score is unchanged.")
	await _snap("team_switch")
	get_tree().quit()
