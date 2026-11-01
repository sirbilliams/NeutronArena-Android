extends Node3D
## Paints every Level surface a unique flat colour and prints the legend (find white/placeholder materials).
var f := 0
var cam: Camera3D
func _ready() -> void:
	var lvl := ArenaLevel.new(); add_child(lvl); lvl.load_level()
	lvl.add_environment()
	var mi: MeshInstance3D = lvl.root.find_child("Level", true, false)
	var m: ArrayMesh = mi.mesh
	for s in m.get_surface_count():
		var old := m.surface_get_material(s)
		var c := Color.from_hsv(fmod(s * 0.137, 1.0), 0.9, 0.5 + 0.5 * fmod(s * 0.31, 1.0))
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = c
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.surface_set_material(s, mat)
		print("LEG %d %s #%s" % [s, old.resource_name if old else "none", c.to_html(false)])
	cam = Camera3D.new(); cam.far = 2000; add_child(cam); cam.current = true
func _process(_d: float) -> void:
	f += 1
	var sj := Vector3(14865, 0, -44200) * Config.WORLD_SCALE
	if f == 5:
		cam.position = sj + Vector3(3.5, 3.2, 5.5); cam.look_at(sj + Vector3(0, 8, -40))
	if f == 20:
		get_viewport().get_texture().get_image().save_png("/home/bill/Projects/arena-assets/shots/map/mat_sign.png")
		cam.position = sj + Vector3(-3, 3.2, 5.5); cam.look_at(sj + Vector3(-40, 3, -10))
	if f == 35:
		get_viewport().get_texture().get_image().save_png("/home/bill/Projects/arena-assets/shots/map/mat_left.png"); get_tree().quit()
