extends Node3D
## Loadout screenshots. Run: tools/vrun.sh res://tools/shots_loadout.tscn -- --out=DIR
var world: World
var cam: Camera3D
var out := "/home/bill/Projects/arena-assets/shots/loadouts"
var f := 0
var plan := []
var menu: LoadoutMenu
var a: Player
var b: Player

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	world = World.new(); add_child(world)
	print("build ", world.build())
	cam = Camera3D.new(); cam.far = 2000; add_child(cam); cam.current = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	var mid := Vector3(20, 0, -120)
	world.c_add_player(3, 0, Transform3D(Basis(Vector3.UP, 0.0), mid + Vector3(0, 0.1, 3)))
	world.c_add_player(4, 1, Transform3D(Basis(Vector3.UP, PI), mid + Vector3(0, 0.1, -5)))
	a = world.players[3]; b = world.players[4]
	for p in [a, b]:
		p.is_local = false
		if p.cam: p.cam.current = false
	cam.current = true
	a.model_yaw = 0.0
	b.model_yaw = PI
	a.t_yaw = 0.0; b.t_yaw = PI
	var lo := CanvasLayer.new(); lo.layer = 10; add_child(lo)
	menu = (load("res://scenes/loadout_menu.tscn") as PackedScene).instantiate() as LoadoutMenu
	menu.visible = false
	lo.add_child(menu)
	plan = [
		[10, func(): menu.visible = true; menu.set_loadout(Loadout.from_class(&"blaster")); menu.set_info("First spawn: pick your loadout, it applies now."); menu.focus_first()],
		[25, func(): _snap("loadout_menu"); menu.visible = false],
		# jetpack
		[26, func():
			a.set_loadout(Loadout.from_class(&"sky_jockey"), 100)
			a.position.y += 1.6; a.t_pos = a.position; a.t_flags = 1
			_cam(mid + Vector3(3.2, 2.2, 5.5), mid + Vector3(0, 1.8, 3), 60)],
		[45, func(): _snap("jetpack")],
		# shrink ray
		[46, func():
			a.position.y -= 1.6; a.t_pos = a.position; a.t_flags = 0
			a.set_loadout(Loadout.from_class(&"blaster"), 100)
			b.set_status("shrink", 99.0)
			world.c_beam(3, a.muzzle(), b.global_position + Vector3(0, 0.5, 0))
			_cam(mid + Vector3(1.6, 1.5, -1.2), mid + Vector3(0, 0.8, -3.5), 60)],
		[52, func(): world.c_beam(3, a.muzzle(), b.global_position + Vector3(0, 0.5, 0))],
		[56, func(): _snap("shrink_ray")],
		# shield + laser trap
		[57, func():
			b.set_status("shrink", 0.0)
			b.set_loadout(Loadout.from_class(&"inventor"), 100)
			b.set_status("shield", 99.0, 60.0)
			world.c_trap(1, 3, 0, mid + Vector3(-2, 0.6, 0.5), mid + Vector3(2, 0.6, 0.5))
			_cam(mid + Vector3(1.6, 1.5, -1.2), mid + Vector3(0, 0.8, -3.5), 60)],
		[70, func(): _snap("shield_trap")],
		# rocket ship ultimate
		[71, func():
			a.set_loadout(Loadout.from_class(&"inventor"), 100)
			a.position.y += 2.5; a.t_pos = a.position
			a.set_status("ult", 8.0)
			var r := Bubble.new(); r.world = world
			r.setup(WeaponData.get_weapon(&"rocket"), 3, 0, a.position + Vector3(0.0, 1.0, -3.0), Vector3(0, 0, -1)); r.velocity = Vector3.ZERO
			world.bubbles_root.add_child(r)
			_cam(mid + Vector3(4.5, 4.5, 6.0), mid + Vector3(0, 3.0, 1.0), 65)],
		[95, func(): _snap("rocket_ultimate")],
		# jeep + goof boots glide
		[96, func():
			a.set_loadout(Loadout.from_class(&"blaster"), 100)
			a.set_status("ult", 8.0)
			_cam(mid + Vector3(4.5, 2.5, 6.0), mid + Vector3(0, 1.0, 2.5), 65)],
		[115, func(): _snap("jeep_ultimate"); get_tree().quit()],
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
