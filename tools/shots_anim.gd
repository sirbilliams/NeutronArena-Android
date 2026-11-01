extends Node3D
## Movement-polish screenshots (side-on close-ups, curb step sequence, jetpack, jump / fall).
## tools/vrun.sh res://tools/shots_move.tscn -- --out=DIR
var out := "/home/bill/Projects/arena-assets/shots/move"
var cam: Camera3D
class StubWorld extends Node:
	var match_over := false
	func local_team() -> int:
		return 0

func box(pos: Vector3, size: Vector3, col: Color) -> void:
	var sb := StaticBody3D.new(); sb.collision_layer = 1
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; cs.shape = sh; sb.add_child(cs)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm
	var mat := StandardMaterial3D.new(); mat.albedo_color = col; mi.material_override = mat
	sb.add_child(mi); sb.position = pos; add_child(sb)

func mk(team: int, pos: Vector3, local: bool, movement := &"") -> Player:
	var p := Player.new()
	p.peer_id = 1 if local else 99
	p.team = team
	p.world = StubWorld.new()
	p.position = pos
	if movement != &"":
		var lo := Loadout.default_loadout(); lo["movement"] = movement
		p.loadout = lo
	add_child(p)
	if not local:
		p.t_pos = pos
	return p

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)

var base := Vector3(31.5, 0.0, -12.54)   # Carl city street, 4.7 m east of the curb at x=27.83
var lvl: ArenaLevel

func look(at: Vector3, dist := 3.2, h := 0.8, back := false) -> void:
	cam.global_position = at + (Vector3(-dist, h - at.y, 0.0) if back else Vector3(0, h - at.y, dist))
	cam.look_at(at, Vector3.UP)

func gy(x: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 1.5, base.z), Vector3(x, -3.0, base.z), 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r.position.y if r else 0.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	Config.test_mode = true
	lvl = ArenaLevel.new(); add_child(lvl); lvl.load_level(); lvl.add_environment()
	cam = Camera3D.new(); cam.fov = 40; cam.far = 500; add_child(cam); cam.current = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	for team in [0, 1]:
		var tag := "jimmy" if team == 0 else "negatron"
		var me := mk(team, Vector3(base.x - 14, gy(base.x - 14) + 0.02, base.z), true)
		me.cam.current = false
		cam.current = true
		me.cam_yaw = 0.0
		await get_tree().create_timer(1.0).timeout
		me.test_move = Vector2(1, 0)   # runs +x
		await get_tree().create_timer(1.0).timeout
		var k := 0
		for view in ["back", "side", "front34"]:
			for i in 3:
				var p := me.global_position
				var off: Vector3 = {"back": Vector3(-3.0, 1.1, 0.0), "side": Vector3(0.0, 0.9, 3.2), "front34": Vector3(3.0, 1.1, 2.0)}[view]
				cam.global_position = p + off
				cam.look_at(p + Vector3(0, 0.8, 0), Vector3.UP)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/run_%s_%s_%d.png" % [out, tag, view, i])
				await get_tree().create_timer(0.07).timeout
		me.queue_free()
		await get_tree().physics_frame
	print("done")
	get_tree().quit()
