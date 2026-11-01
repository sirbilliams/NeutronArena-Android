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
	cam = Camera3D.new(); cam.fov = 35; cam.far = 500; add_child(cam); cam.current = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	var FACE := -PI / 2.0   # facing +x
	var xa := base.x - 0.75
	var xb := base.x + 0.75
	var j := mk(0, Vector3(xa, gy(xa) + 0.02, base.z), false)
	var n := mk(1, Vector3(xb, gy(xb) + 0.02, base.z), false)
	for p in [j, n]:
		p.model_yaw = FACE; p.t_yaw = FACE
	await get_tree().create_timer(1.2).timeout
	look(Vector3(base.x, 0.7, base.z), 4.6, 0.9)
	await get_tree().create_timer(0.5).timeout
	await shot("idle_both")
	for p in [j, n]: p.t_speed = 6.0
	await get_tree().create_timer(0.6).timeout
	await shot("run_both_a")
	await get_tree().create_timer(0.11).timeout
	await shot("run_both_b")
	for p in [j, n]: p.t_speed = 1.8
	await get_tree().create_timer(0.5).timeout
	await shot("walk_both")
	# one on the sidewalk, one on the road, either side of the curb at x=27.83
	for p in [j, n]: p.t_speed = 0.0
	var xj := 27.0; var xn := 28.7
	j.position = Vector3(xj, gy(xj) + 0.02, base.z); n.position = Vector3(xn, gy(xn) + 0.02, base.z); j.t_pos = j.position; n.t_pos = n.position
	look(Vector3(27.85, 0.4, base.z), 4.0, 0.7)
	await get_tree().create_timer(0.9).timeout
	await shot("curb_idle")
	# jump / fall poses (puppets: vertical motion drives the pose)
	j.position = Vector3(xa, gy(xa) + 0.02, base.z); n.position = Vector3(xb, gy(xb) + 0.02, base.z); j.t_grounded = false; n.t_grounded = false
	look(Vector3(base.x, 1.2, base.z), 4.6, 1.2)
	for i in 14:
		j.position.y += 0.07; n.position.y += 0.07; j.t_pos = j.position; n.t_pos = n.position
		await get_tree().physics_frame
	await shot("jump_up")
	for i in 12:
		j.position.y -= 0.07; n.position.y -= 0.07; j.t_pos = j.position; n.t_pos = n.position
		await get_tree().physics_frame
	await shot("fall_down")
	# jetpack
	j.queue_free(); n.queue_free()
	await get_tree().physics_frame
	var jj := mk(0, Vector3(xa, gy(xa) + 0.02, base.z), false, &"jetpack")
	var nn := mk(1, Vector3(xb, gy(xb) + 0.02, base.z), false, &"jetpack")
	for p in [jj, nn]:
		p.model_yaw = FACE; p.t_yaw = FACE
	await get_tree().create_timer(0.8).timeout
	look(Vector3(base.x, 0.8, base.z), 3.2, 0.9)
	await shot("jetpack_idle_side")
	look(Vector3(base.x, 0.8, base.z), 3.2, 0.9, true)
	await shot("jetpack_idle_back")
	for p in [jj, nn]:
		p.position.y += 1.2; p.t_pos = p.position
		p.t_grounded = false; p.t_flags = 1
	await get_tree().create_timer(0.8).timeout
	look(Vector3(base.x, 2.3, base.z), 4.2, 2.3)
	await shot("jetpack_side")
	look(Vector3(base.x, 2.3, base.z), 4.2, 2.3, true)
	await shot("jetpack_back")
	# curb step sequence with a real local player
	jj.queue_free(); nn.queue_free()
	await get_tree().physics_frame
	var me := mk(0, Vector3(24.8, gy(24.8) + 0.02, base.z), true)
	me.model_yaw = FACE
	me.cam.current = false
	cam.current = true
	me.cam_yaw = 0.0
	await get_tree().create_timer(1.0).timeout
	me.test_move = Vector2(1, 0)
	var k := 0
	var idx := 0
	while me.global_position.x < 29.6 and k < 600:
		await get_tree().physics_frame
		k += 1
		var x := me.global_position.x
		if x > 26.4 and k % 3 == 0 and idx < 8:
			idx += 1
			look(Vector3(x + 0.3, 0.45, base.z), 3.4, 0.7)
			await shot("curb_seq_%02d" % idx)
	print("done")
	get_tree().quit()
