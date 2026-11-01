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
	var sj := world.level.spawn_point(0, 0)
	var sn := world.level.spawn_point(1, 0)
	world.c_add_player(1, 0, sj)
	world.c_add_player(2, 1, sn)
	# duel pair mid street (z=-150 .. strip), facing each other
	var mid := Vector3(9100, 0, -37600) * Config.WORLD_SCALE
	world.c_add_player(3, 0, Transform3D(Basis(Vector3.UP, 0.0), mid + Vector3(0, 0.1, 3)))
	world.c_add_player(4, 1, Transform3D(Basis(Vector3.UP, PI), mid + Vector3(0, 0.1, -3)))
	world.players[1].is_local = false
	for id in [1, 2, 3, 4]:
		var p: Player = world.players[id]
		p.is_local = false
		if p.cam: p.cam.current = false
	cam.current = true
	var b := Bubble.new(); b.world = world
	b.setup(WeaponData.get_weapon(&"bubble_gun"), 3, 0, mid + Vector3(0, 1.0, 1.2), Vector3(0, 0, -1)); b.velocity = Vector3.ZERO
	world.bubbles_root.add_child(b)
	plan = [
		[10, func(): _cam(sj.origin + Vector3(-4.5, 2.4, 6.5) , sj.origin + Vector3(1.5, 3.0, -8), 75)],
		[25, func(): _snap("base_jimmy_candybar")],
		[26, func(): _cam(sj.origin + Vector3(0, 7, -12), sj.origin + Vector3(0, 6, -40), 75)],
		[40, func(): _snap("candybar_sign_view")],
		[41, func(): _cam(sn.origin + Vector3(-3.0, 2.4, 6.0), sn.origin + Vector3(1.0, 1.5, -6.0), 75)],
		[55, func(): _snap("base_negatron_museum")],
		[56, func(): _cam(mid + Vector3(5.5, 2.0, 7.0), mid + Vector3(0, 0.9, 0), 60)],
		[70, func(): _snap("duel_midstreet")],
		[71, func(): _cam(mid + Vector3(-12, 9, 22), mid + Vector3(2, 0, -4), 70)],
		[78, func(): _snap("mid_wide")],
		[85, func(): cam.size = 200; cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.rotation_degrees = Vector3(-90, 0, 0); cam.position = Vector3(70, 300, -265)],
		[100, func(): _snap("top_down"); get_tree().quit()],
	]

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
