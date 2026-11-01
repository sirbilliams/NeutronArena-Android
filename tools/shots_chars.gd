extends Node3D
## Roster shots on a flat floor: every character running from behind / side, plus head close-ups (red eyes for the clones).
## tools/vrun.sh res://tools/shots_chars.tscn -- --out=DIR [--ids=carl,ecarl]
var out := "/home/bill/Projects/arena-assets/shots/chars"
var cam: Camera3D
class StubWorld extends Node:
	var match_over := false
	func local_team() -> int:
		return 0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])

func _ready() -> void:
	var ids: Array = Characters.ORDER.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		elif a.begins_with("--ids="): ids = Array(a.substr(6).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	Config.test_mode = true
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.45, 0.6, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 40, 0); add_child(sun)
	var sb := StaticBody3D.new(); sb.collision_layer = 1
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(400, 2, 40); cs.shape = sh; sb.add_child(cs)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(400, 2, 40); mi.mesh = bm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.35, 0.4, 0.35); mi.material_override = mat; sb.add_child(mi)
	sb.position = Vector3(0, -1, 0); add_child(sb)
	cam = Camera3D.new(); cam.fov = 40; cam.far = 500; add_child(cam); cam.current = true
	var n := 0
	for id in ids:
		var sid := StringName(id)
		if not Characters.available(sid):
			print("locked ", id); continue
		var p := Player.new()
		p.peer_id = 1; p.team = Characters.ROSTER[sid].team; p.world = StubWorld.new()
		var lo := Loadout.default_loadout(); lo["char"] = sid; p.loadout = lo
		p.position = Vector3(n * 40.0 - 40.0, 0.05, 0.0)   # own lane per character keeps the shots clean
		add_child(p)
		p.cam.current = false
		cam.current = true
		p.cam_yaw = 0.0
		cam.get_parent().remove_child(cam)
		p.add_child(cam)   # the camera rides with the runner: framing independent of frame time
		await get_tree().create_timer(0.8).timeout
		p.test_move = Vector2(1, 0)
		await get_tree().create_timer(1.0).timeout
		print(id, " model_char=", p.model_char, " vel=", p.velocity, " gait=", p.gait, " clip=", p.cur_anim)
		for view in [["back", Vector3(-3.0, 1.0, 0.0)], ["side", Vector3(0.0, 0.9, 3.2)], ["front", Vector3(3.2, 1.0, 0.8)]]:
			cam.fov = 40
			cam.position = view[1]
			cam.look_at(p.global_position + Vector3(0, 0.7, 0))
			for i in 2: await get_tree().process_frame
			await shot("run_%s_%s" % [id, view[0]])
		p.test_move = Vector2.ZERO
		await get_tree().create_timer(0.8).timeout
		var hy: float = {&"carl": 1.06, &"sheen": 0.98, &"cindy": 1.08, &"libby": 0.98, &"jimmy": 1.15, &"negatron": 1.15}.get(Characters.base_of(sid), 1.1) * p.char_k
		cam.fov = 24
		cam.position = Vector3(1.15, hy + 0.02, 0.18)
		cam.look_at(p.global_position + Vector3(0, hy, 0))
		for i in 2: await get_tree().process_frame
		await shot("eyes_%s" % id)
		cam.fov = 40
		cam.position = Vector3(2.6, 1.0, 1.6)
		cam.look_at(p.global_position + Vector3(0, 0.7, 0))
		for i in 2: await get_tree().process_frame
		await shot("idle_%s" % id)
		p.queue_free()
		n += 1
	get_tree().quit()
