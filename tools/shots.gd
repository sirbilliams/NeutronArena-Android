extends Node3D
## Offline screenshots of bases + player models. Run via tools/vrun.sh res://tools/shots.tscn -- --out=DIR
var world: World
var cam: Camera3D
var out := "/home/bill/Projects/arena-assets/shots"
var f := 0
var plan := []   # [frame, callable]

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	world = World.new(); add_child(world)
	print("build ", world.build())
	cam = Camera3D.new(); cam.far = 2000; add_child(cam); cam.current = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	var lv := world.level
	var sj := lv.spawn_point(0, 0)
	var sn := lv.spawn_point(1, 0)
	var zt := [[0, 0], [0, 1], [1, 0], [1, 1]]   # [team, zone] forward zones
	var pid := 1
	world.c_add_player(pid, 0, sj); pid += 1
	world.c_add_player(pid, 1, sn); pid += 1
	var zs := []
	for z in zt:
		var tr := lv.spawn_point(z[0], 0, z[1])
		var tr2 := lv.spawn_point(z[0], 2, z[1])
		world.c_add_player(pid, z[0], tr); pid += 1
		world.c_add_player(pid, z[0], tr2); pid += 1
		zs.append(tr)
	for id in world.players:
		var p: Player = world.players[id]
		p.is_local = false
		if p.cam: p.cam.current = false
	cam.current = true
	# zone markers for the top-down view (flat coloured discs, hidden until then)
	var marks := Node3D.new(); marks.visible = false; add_child(marks)
	for team in 2:
		var zl: Array = lv.zones[team]
		for i in zl.size():
			var m := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = 12.0; cm.bottom_radius = 12.0; cm.height = 2.0
			m.mesh = cm
			var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var base_c: Color = Config.TEAM_COLORS[team]
			mat.albedo_color = base_c if i == zl.size() - 1 else base_c.lightened(0.5)
			m.material_override = mat
			var c := lv.raw_to_world(zl[i].raw); c.y = 60.0
			m.position = c
			marks.add_child(m)
	var mid := Vector3(9100, 0, -37600) * Config.WORLD_SCALE
	plan = [
		[10, func(): _cam(sj.origin + Vector3(-4.5, 2.4, 6.5), sj.origin + Vector3(1.5, 3.0, -8), 75)],
		[25, func(): _snap("base_jimmy_candybar")],
		[26, func(): _cam(sn.origin + Vector3(-3.0, 2.4, 6.0), sn.origin + Vector3(1.0, 2.5, -8.0), 75)],
		[40, func(): _snap("base_negatron_museum")],
		[41, func(): _fwd(zs[0], 4.5)],
		[55, func(): _snap("fwd_jimmy_1")],
		[56, func(): _fwd(zs[1], 4.5)],
		[70, func(): _snap("fwd_jimmy_2")],
		[71, func(): _fwd(zs[2], 4.5)],
		[85, func(): _snap("fwd_negatron_1")],
		[86, func(): _fwd(zs[3], 4.5)],
		[100, func(): _snap("fwd_negatron_2")],
		[101, func(): marks.visible = true; cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.keep_aspect = Camera3D.KEEP_WIDTH; cam.size = 480; cam.far = 4000; cam.global_position = Vector3(55, 300, -110); cam.rotation_degrees = Vector3(-90, 90, 0)],
		[120, func(): _snap("top_down_zones"); get_tree().quit()],
	]

func _fwd(tr: Transform3D, back: float) -> void:
	var fwd := -tr.basis.z
	_cam(tr.origin - fwd * back + Vector3(0, 2.2, 0) + tr.basis.x * 2.0, tr.origin + fwd * 6.0 + Vector3(0, 1.5, 0), 75)

func _cam(pos: Vector3, look: Vector3, fov: float) -> void:
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = fov
	cam.global_position = pos
	cam.look_at(look)

func _process(_d: float) -> void:
	f += 1
	for s in plan:
		if s[0] == f: s[1].call()

func _snap(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
	print("saved ", n)
