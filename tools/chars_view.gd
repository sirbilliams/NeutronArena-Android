extends Node3D
## Character viewer: each CharModel character, clip + angle grid. tools/vrun.sh res://tools/chars_view.tscn -- --out=DIR [--ids=carl,cindy] [--clip=run]
var out := "/home/bill/Projects/arena-assets/shots/chars"
var cam: Camera3D

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)

func _ready() -> void:
	var ids := ["carl", "cindy", "sheen", "libby", "ecarl", "ecindy", "esheen", "elibby"]
	var clip := "run"
	var t := 0.2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		elif a.begins_with("--ids="): ids = a.substr(6).split(",")
		elif a.begins_with("--clip="): clip = a.substr(7)
		elif a.begins_with("--t="): t = float(a.substr(4))
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.35, 0.45, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); add_child(sun)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(20, 20); floor.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.3, 0.3, 0.3); floor.material_override = fm; add_child(floor)
	cam = Camera3D.new(); cam.fov = 35; add_child(cam); cam.current = true
	for id in ids:
		var m := CharModel.build(StringName(id))
		if m == null:
			print("no model ", id); continue
		m.scale = Vector3.ONE * Config.WORLD_SCALE * float(m.get_meta("k"))
		m.rotation.y = Player.MODEL_YAW
		var roles: Dictionary = m.get_meta("roles")
		var cn: String = roles.get(clip, "")
		var lift := FootTable.lift(cn)
		m.position.y = lift
		add_child(m)
		var ap := m.get_node("AnimationPlayer") as AnimationPlayer
		print(id, " clip ", cn, " roles ", roles)
		if cn != "":
			ap.play(cn); ap.seek(t, true); ap.pause()
		await get_tree().process_frame
		for view in [["back", Vector3(0, 0.9, 3.2)], ["side", Vector3(3.2, 0.9, 0)], ["front", Vector3(0, 0.9, -3.2)], ["head", Vector3(0.0, 1.45, -0.9)]]:
			cam.global_position = view[1]
			cam.look_at(Vector3(0, 1.3 if view[0] == "head" else 0.7, 0))
			if view[0] == "head": cam.fov = 28
			else: cam.fov = 35
			await shot("view_%s_%s_%s" % [id, clip, view[0]])
		m.queue_free()
	get_tree().quit()
