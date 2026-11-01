extends Node3D
## Feel screenshots: contact sheets (12 consecutive frames) of walk / run / strafe / backpedal from the side and from behind.
## tools/vrun.sh res://tools/shots_feel.tscn -- --out=DIR
var out := "/home/bill/Projects/arena-assets/shots/feel"
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


var frames: Array[Image] = []
var cur: Player
var cdir := Vector3.ZERO

func follow(back: bool) -> void:
	var at := cur.position + Vector3(0, 0.6, 0)
	cam.global_position = at + (Vector3(-6.0, 0.3, 0) if back else Vector3(0, 0.3, 6.0))
	cam.look_at(at, Vector3.UP)

func sheet(name: String, back: bool, spd: float, dir: Vector3, n := 12, step := 2) -> void:
	var FACE := -PI / 2.0
	if cur: cur.queue_free()
	await get_tree().physics_frame
	var start := Vector3(base.x - 1.0 * dir.x, 0, base.z - 1.0 * dir.z)
	start.y = gy(start.x) + 0.02
	cur = mk(0, start, false)
	cur.model_yaw = FACE; cur.t_yaw = FACE
	frames.clear()
	for i in 45:
		cur.t_pos += dir * spd / 60.0; cur.t_pos.y = gy(cur.t_pos.x) + 0.02; cur.t_speed = spd
		await get_tree().physics_frame
	for k in n:
		for s in step:
			cur.t_pos += dir * spd / 60.0; cur.t_pos.y = gy(cur.t_pos.x) + 0.02; cur.t_speed = spd
			await get_tree().physics_frame
		follow(back)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var c := cam.unproject_position(cur.position + Vector3(0, 0.6, 0))
		var r := Rect2i(int(c.x) - 200, int(c.y) - 260, 400, 520)
		frames.append(img.get_region(r))
	var cols := 6
	var sh := Image.create(400 * cols, 520 * ((n + cols - 1) / cols), false, Image.FORMAT_RGB8)
	for i in frames.size():
		sh.blit_rect(frames[i], Rect2i(0, 0, 400, 520), Vector2i((i % cols) * 400, (i / cols) * 520))
	sh.save_png("%s/%s.png" % [out, name])
	print("sheet ", name, " gait ", cur.gait, " anim ", cur.cur_anim, " rev ", cur.strafe_rev, " on ", cur.strafe_on, " tw ", cur.tw_cur, " spd_scale ", cur.anim.speed_scale)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	Config.test_mode = true
	lvl = ArenaLevel.new(); add_child(lvl); lvl.load_level(); lvl.add_environment()
	cam = Camera3D.new(); cam.fov = 35; cam.far = 500; add_child(cam); cam.current = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	var X := Vector3(1, 0, 0)
	var Z := Vector3(0, 0, 1)
	for back in [false, true]:
		var v := "behind" if back else "side"
		await sheet("walk_%s" % v, back, 0.9, X)
		await sheet("run_%s" % v, back, 4.5, X)
		await sheet("strafe_right_%s" % v, back, 4.0, Z)
		await sheet("strafe_left_%s" % v, back, 4.0, -Z)
		await sheet("backpedal_%s" % v, back, 3.5, -X)
	get_tree().quit()
