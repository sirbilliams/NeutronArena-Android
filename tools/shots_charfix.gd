extends Node3D
## Character-fix shots: run / jump (blaster: boots), jetpack (sky jockey) and scooter ultimate per roster id, side + back views.
## tools/vrun.sh res://tools/shots_charfix.tscn -- --out=DIR [--ids=carl,libby] [--modes=run,jump,jet,scooter]
var out := "/home/bill/Projects/arena-assets/shots/charfix"
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
	var modes := ["run", "jump", "jet", "scooter"]
	var bv := []   # boot variants [size, offset] (mode jump, through Characters.debug_gear)
	var jv := []   # jetpack origin variants (raw units) applied through Characters.debug_gear, mode jet only
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		elif a.begins_with("--ids="): ids = Array(a.substr(6).split(","))
		elif a.begins_with("--modes="): modes = Array(a.substr(8).split(","))
		elif a.begins_with("--bv="):
			for v in a.substr(5).split(":"):
				var c := v.split(",")
				bv.append([float(c[0]), Vector3(float(c[1]), float(c[2]), float(c[3]))])
		elif a.begins_with("--jv="):
			for v in a.substr(5).split(":"):
				var c := v.split(",")
				jv.append([Vector3(float(c[0]), float(c[1]), float(c[2])), float(c[3]) if c.size() > 3 else 1.0])
	DirAccess.make_dir_recursive_absolute(out)
	Config.test_mode = true
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.45, 0.6, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 40, 0); add_child(sun)
	var sb := StaticBody3D.new(); sb.collision_layer = 1
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(800, 2, 40); cs.shape = sh; sb.add_child(cs)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(800, 2, 40); mi.mesh = bm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.35, 0.4, 0.35); mi.material_override = mat; sb.add_child(mi)
	sb.position = Vector3(0, -1, 0); add_child(sb)
	cam = Camera3D.new(); cam.fov = 40; cam.far = 500; add_child(cam); cam.current = true
	var n := 0
	for id in ids:
		var sid := StringName(id)
		if not Characters.available(sid):
			print("locked ", id); continue
		var tasks := []
		for mode in modes:
			for vi in (maxi(jv.size(), 1) if mode == "jet" else (maxi(bv.size(), 1) if mode == "jump" else 1)):
				tasks.append([mode, vi])
		for task in tasks:
			var mode: String = task[0]
			var vi: int = task[1]
			if mode == "jet" and not jv.is_empty():
				var xf: Transform3D = Characters.GEAR.get(Characters.base_of(sid), {}).get("jet", Balance.JETPACK_XF)
				xf.origin = jv[vi][0]
				xf.basis = xf.basis.orthonormalized() * jv[vi][1]
				Characters.debug_gear = {Characters.base_of(sid): {"jet": xf}}
			if mode == "jump" and not bv.is_empty():
				Characters.debug_gear = {Characters.base_of(sid): {"boot_size": bv[vi][0], "boot_off": bv[vi][1]}}
			var p := Player.new()
			p.peer_id = 1; p.team = Characters.ROSTER[sid].team; p.world = StubWorld.new()
			var lo := Loadout.from_class(&"sky_jockey" if mode == "jet" else &"blaster"); lo["char"] = sid; p.loadout = lo
			p.position = Vector3(n * 40.0 - 40.0, 0.05, 0.0)
			n += 1
			add_child(p)
			p.cam.current = false
			p.cam_yaw = 0.0
			cam.get_parent().remove_child(cam)
			p.add_child(cam)
			await get_tree().create_timer(0.6).timeout
			if mode == "scooter":
				p.set_status("ult", 99.0)
			p.test_move = Vector2(1, 0)
			await get_tree().create_timer(0.9).timeout
			if mode == "jump":
				p.test_jump = true
				await get_tree().create_timer(0.28).timeout
			elif mode == "jet":
				# test mode has no live input: show the thrust pose as a remote player (synced flags, hovering)
				p.test_move = Vector2.ZERO
				p.is_local = false
				p.t_flags = 1
				p.t_grounded = false
				p.position.y = 1.5
				p.t_pos = p.position
				p.t_speed = 0.0
				p.model_yaw = -PI / 2.0
				p.t_yaw = -PI / 2.0
				await get_tree().create_timer(0.6).timeout
			print(id, " ", mode, " model_char=", p.model_char, " clip=", p.cur_anim, " flags=", p.eff_flags(), " y=", p.position.y)
			for view in [["side", Vector3(0.0, 0.9, 3.2)], ["back", Vector3(-3.0, 1.0, 0.0)]]:
				cam.fov = 40
				cam.position = view[1] + Vector3(0, 0.0, 0)
				cam.look_at(p.global_position + Vector3(0, 0.7, 0))
				for i in 2: await get_tree().process_frame
				await shot("%s_%s_%s%s" % [mode, id, view[0], str(vi) if ((mode == "jet" and not jv.is_empty()) or (mode == "jump" and not bv.is_empty())) else ""])
			cam.get_parent().remove_child(cam)
			add_child(cam)
			p.queue_free()
			await get_tree().process_frame
	get_tree().quit()
