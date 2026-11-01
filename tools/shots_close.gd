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

func mk(team: int, pos: Vector3, local: bool, movement := &"", primary := &"", gadget := &"") -> Player:
	var p := Player.new()
	p.peer_id = 1 if local else 99
	p.team = team
	p.world = StubWorld.new()
	p.position = pos
	if movement != &"" or primary != &"" or gadget != &"":
		var lo := Loadout.default_loadout()
		if movement != &"": lo["movement"] = movement
		if primary != &"": lo["primary"] = primary
		if gadget != &"": lo["gadget"] = gadget
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

func put(p: Player, v: String, at: Vector3) -> void:
	var c := p.global_position + at
	cam.global_position = p.global_position + ({"side": Vector3(0, 0.9, 2.6), "back": Vector3(-2.6, 1.0, 0.0), "front": Vector3(2.6, 1.0, 0.8), "top": Vector3(0.5, 2.8, 1.6)}[v])
	cam.look_at(p.global_position + Vector3(0, 0.8, 0), Vector3.UP)

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	Config.test_mode = true
	lvl = ArenaLevel.new(); add_child(lvl); lvl.load_level(); lvl.add_environment()
	cam = Camera3D.new(); cam.fov = 38; cam.far = 500; add_child(cam); cam.current = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	var FACE := -PI / 2.0
	var pos := Vector3(base.x, gy(base.x) + 0.02, base.z)
	for team in [0]:
		var cases := [["plating", &"none", &"", 0.75, 1.6]]
		for cs in cases:
			var p := mk(team, pos, true, cs[1], &"", cs[2])
			p.cam.current = false; cam.current = true
			p.model_yaw = FACE; p.cam_yaw = 0.0
			if cs[0] == "shield": p.set_status("shield", 9.0, 60.0)
			if cs[0] == "drone": p.set_status("drone", 9.0)
			await get_tree().create_timer(0.9).timeout
			for v in [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]:
				cam.global_position = p.global_position + Vector3(0, cs[3] + 0.1, 0) + v.normalized() * cs[4]
				cam.look_at(p.global_position + Vector3(0, cs[3], 0), Vector3.UP)
				await get_tree().create_timer(0.12).timeout
				await snap("c_%s_%s_%s" % [team, cs[0], str(v.x)])
			p.free()
			await get_tree().physics_frame
	print("done")
	get_tree().quit()
