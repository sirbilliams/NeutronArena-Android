class_name ArenaLevel
extends Node3D
## Loads the Carl city level (level5c.glb) at runtime, builds collision, fences the play area.

# Raw game units (glb space, Y up). The 5v5 map is the street block at the Candy Bar end of the city:
# Jimmy base = Candy Bar front (top street, east end), Negatron base = SW corner of the block (~124 m straight line,
# ~176 m along the streets). The museum end is ~400 m away, too far for a handheld-sized match.
const CANDY_CENTER := Vector3(14865, 0, -44900)
const NEGATRON_CENTER := Vector3(1800, 0, -30500)
const MUSEUM_CENTER := NEGATRON_CENTER   # legacy name used by tests/net_test.gd
## Play area = union of these raw-unit rectangles (x, z, width, depth). The fence is generated around their outline.
const PLAY_RECTS := [
	Rect2(300, -46200, 18600, 17400),   # the street ring + courtyard block (top, left, bottom streets)
	Rect2(8000, -52500, 12500, 6400),   # Candy Bar plaza north of the top street
]
const FENCE_CELL := 250.0   # raw units, outline resolution
const FENCE_HEIGHT := 60.0  # metres
var chunk_raw := 12000.0  # far-field chunk edge (raw units); the play area itself stays one batch (fewest draw calls)
const CORE_MARGIN := 25.0   # metres around the play area kept as a single batch
var drop_dist := 100.0     # metres from the play area: chunks/collision further away are not loaded
var vis_range := 150.0     # metres: chunks are hidden beyond this distance from the camera
const BACKDROP_Y := -467.0  # exporter backdrop plane (3 m pit); raised to just below street level
const SEAT_Y := -30.0
const SPAWN_COLS := 5
const SPAWN_ROWS := 2

var root: Node3D
var body: StaticBody3D
var stats := {"chunks": 0, "dropped": 0}

func _play_bounds() -> Rect2:
	var r: Rect2 = PLAY_RECTS[0]
	for q in PLAY_RECTS:
		r = r.merge(q)
	return r

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
	# the exporter wraps everything in an extra node, so look the groups up by name
	var col := root.find_child("Collision", true, false)
	if col:
		for c in col.get_children():
			if faces.has(c.name):
				_add_trimesh(c.name, faces[c.name], xf_root)
			c.visible = false
	var mk := root.find_child("Markers", true, false)
	if mk:
		mk.visible = false
	var lv := root.find_child("Level", true, false) as MeshInstance3D
	if lv:
		_chunk_level(lv)
	_add_fence()
	_add_cover()
	print("level ready ms=", Time.get_ticks_msec() - t0, " chunks=", stats.chunks, " dropped=", stats.dropped)
	return true

## raw-unit rectangle (x,z) of the play area grown by `m` metres
func _grown(m: float) -> Rect2:
	return _play_bounds().grow(m / Config.WORLD_SCALE)

func _add_trimesh(nm: String, tris: PackedVector3Array, xf_root: Transform3D) -> void:
	if tris.size() < 3:
		return
	# keep only triangles near the play area, and raise the exporter backdrop plane (3 m pits)
	var keep := _grown(drop_dist * 0.35)
	var out := PackedVector3Array()
	var n := tris.size() / 3
	for i in n:
		var a := tris[i * 3]; var b := tris[i * 3 + 1]; var c := tris[i * 3 + 2]
		var minx := minf(a.x, minf(b.x, c.x)); var maxx := maxf(a.x, maxf(b.x, c.x))
		var minz := minf(a.z, minf(b.z, c.z)); var maxz := maxf(a.z, maxf(b.z, c.z))
		if maxx < keep.position.x or minx > keep.end.x or maxz < keep.position.y or minz > keep.end.y:
			continue
		if maxf(a.y, maxf(b.y, c.y)) < BACKDROP_Y + 60.0 and nm == "Level":
			a.y = SEAT_Y; b.y = SEAT_Y; c.y = SEAT_Y
		out.append(a); out.append(b); out.append(c)
	if out.size() < 3:
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(xf_root * out)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.name = "col_" + nm
	body.add_child(cs)

## Split the single Level mesh into spatial chunks (frustum culling) and drop/range-limit the far backdrop.
func _chunk_level(mi: MeshInstance3D) -> void:
	var src := mi.mesh as ArrayMesh
	if src == null:
		return
	var core := _grown(CORE_MARGIN)
	var chunks := {}   # Vector2i -> {surface idx -> arrays}
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm = arr[Mesh.ARRAY_NORMAL]
		var uv = arr[Mesh.ARRAY_TEX_UV]
		var idx = arr[Mesh.ARRAY_INDEX]
		var ntri: int = (idx.size() if idx != null and idx.size() > 0 else v.size()) / 3
		for t in ntri:
			var i0: int = idx[t * 3] if idx != null and idx.size() > 0 else t * 3
			var i1: int = idx[t * 3 + 1] if idx != null and idx.size() > 0 else t * 3 + 1
			var i2: int = idx[t * 3 + 2] if idx != null and idx.size() > 0 else t * 3 + 2
			var p0 := v[i0]; var p1 := v[i1]; var p2 := v[i2]
			var raised := maxf(p0.y, maxf(p1.y, p2.y)) < BACKDROP_Y + 60.0
			if raised:
				p0.y = SEAT_Y; p1.y = SEAT_Y; p2.y = SEAT_Y
			var cx := (p0.x + p1.x + p2.x) / 3.0
			var cz := (p0.z + p1.z + p2.z) / 3.0
			var key := Vector2i(-999, -999) if core.has_point(Vector2(cx, cz)) else Vector2i(floori(cx / chunk_raw), floori(cz / chunk_raw))
			var ch: Dictionary = chunks.get_or_add(key, {})
			var d: Dictionary = ch.get_or_add(s, {"v": PackedVector3Array(), "n": PackedVector3Array(), "u": PackedVector2Array()})
			d.v.append(p0); d.v.append(p1); d.v.append(p2)
			if nrm != null:
				d.n.append(Vector3.UP if raised else nrm[i0]); d.n.append(Vector3.UP if raised else nrm[i1]); d.n.append(Vector3.UP if raised else nrm[i2])
			if uv != null:
				d.u.append(uv[i0]); d.u.append(uv[i1]); d.u.append(uv[i2])
	var parent := mi.get_parent()
	var xf := mi.transform
	var play := _play_bounds()
	var sc := Config.WORLD_SCALE
	for key in chunks:
		var m := ArrayMesh.new()
		var mats := []
		for s in chunks[key]:
			var d: Dictionary = chunks[key][s]
			var a := []
			a.resize(Mesh.ARRAY_MAX)
			a[Mesh.ARRAY_VERTEX] = d.v
			if d.n.size() > 0: a[Mesh.ARRAY_NORMAL] = d.n
			if d.u.size() > 0: a[Mesh.ARRAY_TEX_UV] = d.u
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
			m.surface_set_material(m.get_surface_count() - 1, src.surface_get_material(s))
		var bb := m.get_aabb()
		# distance (metres) from the play area to this chunk
		var dx := maxf(maxf(play.position.x - (bb.position.x + bb.size.x), bb.position.x - play.end.x), 0.0)
		var dz := maxf(maxf(play.position.y - (bb.position.z + bb.size.z), bb.position.z - play.end.y), 0.0)
		var dist := sqrt(dx * dx + dz * dz) * sc
		var big := maxf(bb.size.x, bb.size.z) * sc > 250.0
		if dist > drop_dist and not big:
			stats.dropped += 1
			continue
		var inst := MeshInstance3D.new()
		inst.name = "chunk_%d_%d" % [key.x, key.y]
		inst.mesh = m
		inst.transform = xf
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not big and key.x != -999:
			inst.visibility_range_end = vis_range
			inst.visibility_range_end_margin = 20.0
		parent.add_child(inst)
		stats.chunks += 1
	mi.queue_free()

func raw_to_world(p: Vector3) -> Vector3:
	return p * Config.WORLD_SCALE

func _inside(cx: float, cz: float) -> bool:
	for r in PLAY_RECTS:
		if r.has_point(Vector2(cx, cz)):
			return true
	return false

## Fence along the outline of PLAY_RECTS (several boxes following the street/plaza edges).
func _add_fence() -> void:
	var b := _play_bounds().grow(FENCE_CELL * 2.0)
	var nx := int(ceil(b.size.x / FENCE_CELL))
	var nz := int(ceil(b.size.y / FENCE_CELL))
	var inside := []
	for i in nx:
		var col := []
		for k in nz:
			col.append(_inside(b.position.x + (i + 0.5) * FENCE_CELL, b.position.y + (k + 0.5) * FENCE_CELL))
		inside.append(col)
	var sc := Config.WORLD_SCALE
	var cs_ := FENCE_CELL * sc
	var t := 2.0
	var h := FENCE_HEIGHT
	var cy := h * 0.5 - 10.0
	var boxes := 0
	# walls along x (edges between z-rows), then along z (edges between x-columns)
	for pass_x: bool in [true, false]:
		var outer := nz + 1 if pass_x else nx + 1
		var inner := nx if pass_x else nz
		for e in outer:
			for side: int in [-1, 1]:   # -1: inside is on the low side of the edge, +1: inside on the high side
				var run_start := -1
				for j in inner + 1:
					var hit := false
					if j < inner:
						var lo: bool = (inside[j][e - 1] if e > 0 else false) if pass_x else (inside[e - 1][j] if e > 0 else false)
						var hi: bool = (inside[j][e] if e < nz else false) if pass_x else (inside[e][j] if e < nx else false)
						hit = (lo and not hi) if side == -1 else (hi and not lo)
					if hit and run_start < 0:
						run_start = j
					elif not hit and run_start >= 0:
						var len_m := (j - run_start) * cs_
						var along := b.position.x if pass_x else b.position.y
						var edge_pos := (b.position.y if pass_x else b.position.x) + e * FENCE_CELL
						var mid := (along + (run_start + (j - run_start) * 0.5) * FENCE_CELL) * sc
						var off := edge_pos * sc + side * t * 0.5
						var cs := CollisionShape3D.new()
						var bx := BoxShape3D.new()
						bx.size = Vector3(len_m + t, h, t) if pass_x else Vector3(t, h, len_m + t)
						cs.shape = bx
						cs.position = Vector3(mid, cy, off) if pass_x else Vector3(off, cy, mid)
						cs.name = "fence"
						body.add_child(cs)
						boxes += 1
						run_start = -1
	print("fence boxes=", boxes)

## A few low barriers / crates in mid-map (original geometry, not from the game export).
const COVER := [
	# [raw x, raw z, size metres (x,y,z), yaw degrees]
	[9300, -44900, Vector3(5.0, 1.3, 0.7), 0.0], [8000, -45300, Vector3(1.6, 1.6, 1.6), 20.0], [10700, -44500, Vector3(1.6, 1.0, 1.6), -15.0],
	[9400, -37800, Vector3(0.7, 1.3, 5.0), 0.0], [8200, -37000, Vector3(1.6, 1.6, 1.6), 10.0], [10500, -38700, Vector3(1.6, 1.0, 1.6), 30.0],
	[11200, -30500, Vector3(5.0, 1.3, 0.7), 0.0], [12600, -30900, Vector3(1.6, 1.6, 1.6), -20.0], [9900, -30000, Vector3(1.6, 1.0, 1.6), 5.0],
]

func _add_cover() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.55, 0.45)
	mat.roughness = 0.9
	var cov := Node3D.new()
	cov.name = "Cover"
	add_child(cov)
	for c in COVER:
		var sz: Vector3 = c[2]
		var p := Vector3(c[0], 0, c[1]) * Config.WORLD_SCALE
		p.y = sz.y * 0.5 - 0.02   # street level is y=0
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		mi.material_override = mat
		mi.position = p
		mi.rotation_degrees.y = c[3]
		cov.add_child(mi)
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = sz
		cs.shape = bx
		cs.position = p
		cs.rotation_degrees.y = c[3]
		body.add_child(cs)

func ground_y(world_xz: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(world_xz.x, 12.0, world_xz.z), Vector3(world_xz.x, -30.0, world_xz.z), 1)
	var r := space.intersect_ray(q)
	return r.position.y if r else 0.0

## Spawn points: SPAWN_COLS x SPAWN_ROWS grid in front of the base, facing the other base.
func spawn_point(team: int, idx: int) -> Transform3D:
	var c := CANDY_CENTER if team == Config.TEAM_JIMMY else NEGATRON_CENTER
	var cw := raw_to_world(c)
	var n := idx % (SPAWN_COLS * SPAWN_ROWS)
	var col := n % SPAWN_COLS
	var row := n / SPAWN_COLS
	var p := cw + Vector3((col - (SPAWN_COLS - 1) * 0.5) * 2.0, 0, (row - 0.5) * 2.0)
	p.y = ground_y(p) + 0.1
	var other := raw_to_world(NEGATRON_CENTER if team == Config.TEAM_JIMMY else CANDY_CENTER)
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
