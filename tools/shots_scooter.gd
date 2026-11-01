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
	a.set_loadout(Loadout.from_class(&"blaster"), 100)
	b.set_loadout(Loadout.from_class(&"blaster"), 100)
	a.position = mid + Vector3(-2.5, 0.1, 0); a.t_pos = a.position
	b.position = mid + Vector3(2.5, 0.1, 0); b.t_pos = b.position
	a.model_yaw = 0.0; a.t_yaw = 0.0; b.model_yaw = 0.0; b.t_yaw = 0.0
	a.rotation = Vector3.ZERO; b.rotation = Vector3.ZERO
	a.t_speed = 6.0; b.t_speed = 6.0
	a.set_status("ult", 99.0)
	b.set_status("ult", 99.0)
	plan = [
		[20, func(): _cam(mid + Vector3(0.6, 0.8, 0.0), mid + Vector3(-2.5, 0.5, 0), 55)],
		[40, func(): _snap("scooter_ultimate_jimmy")],
		[41, func(): _cam(mid + Vector3(4.8, 0.6, 0.0), mid + Vector3(2.5, 0.4, 0), 55)],
		[60, func(): _snap("scooter_ultimate_negatron")],
		[61, func(): a.status.clear(); b.status.clear(); _cam(mid + Vector3(1.4, 0.7, 0.0), mid + Vector3(-2.5, 0.5, 0), 55)],
		[80, func(): _snap("gear_check"); get_tree().quit()],
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
