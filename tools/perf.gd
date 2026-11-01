extends Node3D
## Fixed-camera render stats (draw calls, objects, primitives, frame time). Run: tools/vrun.sh res://tools/perf.tscn
## Cameras are fixed world transforms so before/after runs are comparable.
var world: World
var cam: Camera3D
var f := 0
var views := [
	["street_candy", Vector3(98.1, 2.5, -290.0), Vector3(40.0, 2.0, -290.0)],   # Jimmy base, along the top street
	["mid_street", Vector3(60.0, 2.0, -201.0), Vector3(110.0, 3.0, -201.0)],    # bottom street of the first ring
	["museum_ave", Vector3(15.8, 2.0, 84.0), Vector3(15.8, 3.0, 30.0)],         # Negatron base, north along the avenue
	["overview", Vector3(65.0, 250.0, -100.0), Vector3(65.0, 0.0, -90.0)],      # whole route from above
]
var vi := 0
var samples := []
var vp: RID

func _ready() -> void:
	world = World.new(); add_child(world)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--drop="): world.level.drop_dist = float(a.substr(7))
		if a.begins_with("--vis="): world.level.vis_range = float(a.substr(6))
		if a.begins_with("--core="): world.level.core_chunk = float(a.substr(7))
		if a.begins_with("--chunk="): world.level.chunk_raw = float(a.substr(8))
	print("build ", world.build())
	cam = Camera3D.new(); cam.far = 2000; add_child(cam); cam.current = true
	vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	_set_view()

func _set_view() -> void:
	cam.global_position = views[vi][1]
	cam.look_at(views[vi][2])
	samples.clear(); f = 0

func _process(_d: float) -> void:
	f += 1
	if f > 40:
		samples.append([
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
			RenderingServer.viewport_get_measured_render_time_gpu(vp),
			Performance.get_monitor(Performance.TIME_FPS)])
	if f >= 160:
		var a := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		for s in samples:
			for i in 6: a[i] += s[i] / samples.size()
		print("PERF %-14s draws=%d objects=%d prims=%d cpu_ms=%.2f gpu_ms=%.2f fps=%.0f" % [views[vi][0], a[0], a[1], a[2], a[3], a[4], a[5]])
		vi += 1
		if vi >= views.size():
			get_tree().quit()
		else:
			_set_view()
