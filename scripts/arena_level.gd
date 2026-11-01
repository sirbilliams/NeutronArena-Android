class_name ArenaLevel
extends Node3D
## Loads the Carl city level (level5c.glb) at runtime, builds collision, fences the play area.

# Raw game units (glb space, Y up). Two selectable layouts (const LAYOUT, or set `layout_name` before load_level()):
#  "museum" (default): Jimmy = Candy Bar front, Negatron = museum plaza, ~392 m apart, fenced rectangle over the
#                      serpentine street route (blocks between the street legs are open ground = natural flanks).
#  "compact": the street block at the Candy Bar end only (Negatron at its SW corner, ~124 m apart).
const LAYOUT := "museum"
const CANDY_CENTER := Vector3(14865, 0, -44900)
const MUSEUM_CENTER := Vector3(2400, 0, 15200)
const NEGATRON_COMPACT := Vector3(1800, 0, -30500)
const NEGATRON_CENTER := MUSEUM_CENTER   # legacy alias (tests/net_test.gd)
## Per layout: play area = union of raw rectangles (x, z, w, d); fence is generated around their outline.
## route = street centre line Candy -> museum (raw x,z); fwd = forward-zone positions as fractions of the route
## length from Jimmy's base, listed most-forward first per team (Jimmy: larger = more forward; Negatron: smaller).
const LAYOUTS := {
	"museum": {
		"rects": [
			Rect2(300, -46200, 18200, 41200),     # top street .. down the street legs and the blocks between
			Rect2(-1100, -5200, 19600, 19300),    # crossing + z=1200 street + west avenue
			Rect2(-1100, 13000, 13000, 5200),     # museum plaza
			Rect2(8000, -52500, 12500, 6400),     # Candy Bar plaza
		],
		"bases": [Vector3(14865, 0, -44900), Vector3(2400, 0, 15200)],
		"route": [Vector2(14865, -44900), Vector2(1800, -44700), Vector2(1800, -30500), Vector2(16600, -30500),
			Vector2(16600, -19500), Vector2(2400, -19500), Vector2(2400, -9200), Vector2(13400, -9200),
			Vector2(13400, 1200), Vector2(1500, 1200), Vector2(1500, 13000), Vector2(2400, 15200)],
		"fwd": [[0.43, 0.28], [0.57, 0.72]],
		"cover_step": 6000.0,
	},
	"compact": {
		"rects": [
			Rect2(300, -46200, 18600, 17400),   # the street ring + courtyard block (top, left, bottom streets)
			Rect2(8000, -52500, 12500, 6400),   # Candy Bar plaza north of the top street
		],
		"bases": [Vector3(14865, 0, -44900), Vector3(1800, 0, -30500)],
		"route": [Vector2(14865, -44900), Vector2(1800, -44700), Vector2(1800, -30500)],
		"fwd": [[], []],
		"cover_step": 0.0,
	},
}
const ZONE_CLEAR := 25.0   # metres: a forward zone is usable if no living enemy is this close to it
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
var layout_name := LAYOUT
var core_chunk := 0.0       # >0: chunk the play area too (raw units) instead of one batch (tested in tools/perf.gd)
var zones := [[], []]       # per team: [{raw: Vector3, dir: Vector2}] most forward first, base zone last

func _layout() -> Dictionary:
	return LAYOUTS[layout_name]

func _build_zones() -> void:
	var L := _layout()
	var route: Array = L.route
	var total := 0.0
	for i in route.size() - 1:
		total += route[i].distance_to(route[i + 1])
	zones = [[], []]
	for team in 2:
		for fr in L.fwd[team]:
			var q := _route_at(route, fr * total)
			# face the enemy: Jimmy walks along the route, Negatron against it
			var d: Vector2 = q[1] if team == Config.TEAM_JIMMY else -q[1]
			zones[team].append({"raw": Vector3(q[0].x, 0, q[0].y), "dir": d})
		var base: Vector3 = L.bases[team]
		var other: Vector3 = L.bases[1 - team]
		zones[team].append({"raw": base, "dir": Vector2(other.x - base.x, other.z - base.z).normalized()})

## [point, unit tangent] at arclength `s` along a raw polyline
func _route_at(route: Array, s: float) -> Array:
	for i in route.size() - 1:
		var l: float = route[i].distance_to(route[i + 1])
		if s <= l or i == route.size() - 2:
			var t: Vector2 = (route[i + 1] - route[i]).normalized()
			return [route[i] + t * minf(s, l), t]
		s -= l
	return [route[0], Vector2.RIGHT]

## Index of the zone (in zones[team]) a dead player of `team` respawns at: the most forward zone with no
## enemy (world-space positions) within ZONE_CLEAR metres, else the next one back, finally the base.
func choose_zone(team: int, enemy_positions: Array) -> int:
	var zs: Array = zones[team]
	for i in zs.size() - 1:
		var c := raw_to_world(zs[i].raw)
		var clear := true
		for e in enemy_positions:
			if Vector2(e.x - c.x, e.z - c.z).length() < ZONE_CLEAR:
				clear = false
				break
		if clear:
			return i
	return zs.size() - 1

func _rects() -> Array:
	return _layout().rects

func _play_bounds() -> Rect2:
	var r: Rect2 = _rects()[0]
	for q in _rects():
		r = r.merge(q)
	return r

func load_level() -> bool:
	_build_zones()
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
			var key := Vector2i(floori(cx / chunk_raw), floori(cz / chunk_raw))
			if core.has_point(Vector2(cx, cz)):
				key = Vector2i(-999, -999) if core_chunk <= 0.0 else Vector2i(floori(cx / core_chunk), floori(cz / core_chunk) + 100000)
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
	for r in _rects():
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

func _cover_items() -> Array:
	var step: float = _layout().cover_step
	if step <= 0.0:
		return COVER
	var items := []
	var route: Array = _layout().route
	var total := 0.0
	for i in route.size() - 1:
		total += route[i].distance_to(route[i + 1])
	var s := step * 0.6
	var k := 0
	while s < total - step * 0.5:
		var q := _route_at(route, s)
		var pt: Vector2 = q[0]
		var t: Vector2 = q[1]
		var n := Vector2(-t.y, t.x)
		var near_zone := false
		for team in 2:
			for z in zones[team]:
				if Vector2(z.raw.x, z.raw.z).distance_to(pt) * Config.WORLD_SCALE < 14.0:
					near_zone = true
		if not near_zone:
			var side := 1.0 if k % 2 == 0 else -1.0
			var yaw := rad_to_deg(atan2(-t.y, t.x))
			var m := 1.0 / Config.WORLD_SCALE   # 1 metre in raw units
			var w: Vector2 = pt + n * side * 3.5 * m
			items.append([w.x, w.y, Vector3(5.0, 1.3, 0.7), yaw])
			var c1: Vector2 = pt - n * side * 3.0 * m + t * 3.0 * m
			items.append([c1.x, c1.y, Vector3(1.6, 1.6, 1.6), yaw + 20.0])
			var c2: Vector2 = pt - n * side * 4.5 * m - t * 2.0 * m
			items.append([c2.x, c2.y, Vector3(1.6, 1.0, 1.6), yaw - 15.0])
		s += step
		k += 1
	return items

func _add_cover() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.55, 0.45)
	mat.roughness = 0.9
	var items := _cover_items()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	bm.material = mat
	mm.mesh = bm
	mm.instance_count = items.size()
	var cov := MultiMeshInstance3D.new()   # one draw call for all cover
	cov.name = "Cover"
	cov.multimesh = mm
	add_child(cov)
	for i in items.size():
		var c: Array = items[i]
		var sz: Vector3 = c[2]
		var p := Vector3(c[0], 0, c[1]) * Config.WORLD_SCALE
		p.y = sz.y * 0.5 - 0.02   # street level is y=0
		var bas := Basis(Vector3.UP, deg_to_rad(c[3]))
		mm.set_instance_transform(i, Transform3D(bas * Basis.from_scale(sz), p))
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = sz
		cs.shape = bx
		cs.transform = Transform3D(bas, p)
		body.add_child(cs)
	stats["cover"] = items.size() / 3

func ground_y(world_xz: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(world_xz.x, 12.0, world_xz.z), Vector3(world_xz.x, -30.0, world_xz.z), 1)
	var r := space.intersect_ray(q)
	return r.position.y if r else 0.0

## Spawn grid (SPAWN_COLS x SPAWN_ROWS) of a team zone, facing the enemy. zone < 0 = the team's base zone.
func spawn_point(team: int, idx: int, zone := -1) -> Transform3D:
	var zs: Array = zones[team]
	var z: Dictionary = zs[zs.size() - 1 if zone < 0 else zone]
	var cw := raw_to_world(z.raw)
	var dir: Vector2 = z.dir
	var perp := Vector2(-dir.y, dir.x)
	var n := idx % (SPAWN_COLS * SPAWN_ROWS)
	var col := n % SPAWN_COLS
	var row := n / SPAWN_COLS
	var off := perp * (col - (SPAWN_COLS - 1) * 0.5) * 2.0 - dir * (row * 2.0)
	var p := cw + Vector3(off.x, 0, off.y)
	p.y = ground_y(p) + 0.1
	var yaw := atan2(-dir.x, -dir.y)
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
