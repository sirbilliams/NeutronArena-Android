extends Node3D
func _ready() -> void:
	var jp := Assets.load_scene("jetpack.glb") as Node3D
	add_child(jp)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(1,1,1); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.3,0.3,0.4); env.environment = e; add_child(env)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 120; add_child(cam); cam.current = true
	var c := Vector3(26, 1.5, 10)
	var views := {"front_z": Vector3(0,0,200), "side_x": Vector3(200,0,0), "top_y": Vector3(0,200,0)}
	for k in views:
		cam.global_position = c + views[k]
		cam.look_at(c, Vector3.UP if k != "top_y" else Vector3(0,0,-1))
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/home/bill/Projects/arena-assets/shots/move/jp_%s.png" % k)
	get_tree().quit()
