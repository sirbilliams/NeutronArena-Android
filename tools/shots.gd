extends Node3D
## Level calibration shots. Run (needs --write-movie so frames render without a visible window):
## godot --path . res://tools/shots.tscn --write-movie /tmp/x.png --fixed-fps 10 --quit-after 40 -- --out=DIR
var lvl: ArenaLevel
var cam: Camera3D
var out := "/home/bill/Projects/arena-assets/shots"
var f := 0
var steps := []
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	lvl = ArenaLevel.new(); add_child(lvl)
	if not "--nolevel" in OS.get_cmdline_user_args(): print("load ", lvl.load_level())
	lvl.add_environment()
	cam = Camera3D.new(); cam.far = 3000; add_child(cam); cam.current = true
func _process(_d: float) -> void:
	f += 1
	if f % 5 == 0: print(f, " cam=", get_viewport().get_camera_3d(), " ", cam.global_position, " same=", get_viewport().get_camera_3d() == cam)
	if f == 30:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 480
		cam.position = Vector3(65, 300, -100)
		cam.rotation_degrees = Vector3(-90, 0, 0)
	elif f == 50: _snap("top")
	elif f == 60 or f == 120:
		var t := 0 if f == 60 else 1
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 70
		var sp := lvl.spawn_point(t, 0)
		var other := lvl.spawn_point(1 - t, 0).origin
		var dir := (other - sp.origin).normalized()
		print("spawn", t, " ", sp.origin)
		cam.global_position = sp.origin + Vector3(0, 6, 0) - dir * 10
		cam.look_at(sp.origin + Vector3(0, 1, 0) + dir * 6)
	elif f == 100: _snap("base0")
	elif f == 160: _snap("base1"); get_tree().quit()
func _snap(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
	print("saved ", n)
