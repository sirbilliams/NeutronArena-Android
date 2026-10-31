class_name ArenaLevel
extends Node3D
## Loads the Carl city level (level5c.glb) at runtime, builds collision, fences the play area.

# Raw game units (glb space, Y up). Candy Bar = Jimmy base, Museum plaza = Negatron base.
const CANDY_CENTER := Vector3(14865, 0, -44200)
const MUSEUM_CENTER := Vector3(2400, 0, 15200)
# Play-area rectangle (raw x/z) that fences the streets between the two bases.
const FENCE_MIN := Vector2(-1800, -52500)
const FENCE_MAX := Vector2(22500, 17500)
const FENCE_HEIGHT := 60.0  # metres

var root: Node3D
var body: StaticBody3D

func load_level() -> bool:
	var t0 := Time.get_ticks_msec()
	var scn := Assets.load_scene("levels/level5c.glb")
	if scn == null:
		return false
	root = scn as Node3D
	root.scale = Vector3.ONE * Config.WORLD_SCALE
	print("glb loaded ms=", Time.get_ticks_msec() - t0)
	add_child(root)
	body = StaticBody3D.new()
	body.name = "LevelBody"
	body.collision_layer = 1
	add_child(body)
	var xf_root := Transform3D(Basis.from_scale(Vector3.ONE * Config.WORLD_SCALE), Vector3.ZERO)
	var faces := Assets.faces("levels/level5c.glb")
	if faces.has("Level"):
		_add_trimesh("Level", faces["Level"], xf_root)
	var col := root.get_node_or_null("Collision")
	if col:
		for c in col.get_children():
			if faces.has(c.name):
				_add_trimesh(c.name, faces[c.name], xf_root)
			c.visible = false
	var mk := root.get_node_or_null("Markers")
	if mk:
		mk.visible = false
	_add_fence()
	print("level ready ms=", Time.get_ticks_msec() - t0)
	return true

func _add_trimesh(nm: String, tris: PackedVector3Array, xf_root: Transform3D) -> void:
	if tris.size() < 3:
		return
	# bake scale into the faces so the physics body stays unscaled
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(xf_root * tris)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.name = "col_" + nm
	body.add_child(cs)

func raw_to_world(p: Vector3) -> Vector3:
	return p * Config.WORLD_SCALE

func _add_fence() -> void:
	var a := FENCE_MIN * Config.WORLD_SCALE
	var b := FENCE_MAX * Config.WORLD_SCALE
	var t := 2.0
	var h := FENCE_HEIGHT
	var cy := h * 0.5 - 10.0
	var w := b.x - a.x
	var l := b.y - a.y
	var walls := [
		[Vector3(w + 2 * t, h, t), Vector3((a.x + b.x) / 2, cy, a.y - t / 2)],
		[Vector3(w + 2 * t, h, t), Vector3((a.x + b.x) / 2, cy, b.y + t / 2)],
		[Vector3(t, h, l), Vector3(a.x - t / 2, cy, (a.y + b.y) / 2)],
		[Vector3(t, h, l), Vector3(b.x + t / 2, cy, (a.y + b.y) / 2)],
	]
	for wl in walls:
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = wl[0]
		cs.shape = bx
		cs.position = wl[1]
		cs.name = "fence"
		body.add_child(cs)

func ground_y(world_xz: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(world_xz.x, 12.0, world_xz.z), Vector3(world_xz.x, -30.0, world_xz.z), 1)
	var r := space.intersect_ray(q)
	return r.position.y if r else 0.0

## Spawn points: grid in front of the base, facing the arena.
func spawn_point(team: int, idx: int) -> Transform3D:
	var c := CANDY_CENTER if team == Config.TEAM_JIMMY else MUSEUM_CENTER
	var cw := raw_to_world(c)
	var col := idx % 4
	var row := (idx / 4) % 3
	var p := cw + Vector3((col - 1.5) * 2.0, 0, row * 2.0 * (1.0 if team == Config.TEAM_JIMMY else -1.0))
	p.y = ground_y(p) + 0.1
	# face towards the other base
	var other := raw_to_world(MUSEUM_CENTER if team == Config.TEAM_JIMMY else CANDY_CENTER)
	var yaw := atan2(-(other.x - p.x), -(other.z - p.z))
	return Transform3D(Basis(Vector3.UP, yaw), p)

func add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.72, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 0.7
	add_child(sun)
