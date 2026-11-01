class_name Fx
extends RefCounted
## Visual helpers. Models come from the player's own exported assets; everything falls back to primitives.
static func model(rel: String) -> Node3D:
	var n := Assets.try_scene(rel) as Node3D
	if n == null:
		return null
	for ap in n.find_children("*", "AnimationPlayer", true, false):
		var a := ap as AnimationPlayer
		for an in a.get_animation_list():
			a.get_animation(an).loop_mode = Animation.LOOP_LINEAR
		var l := a.get_animation_list()
		if l.size() > 0:
			a.play(l[0])
	return n

static func mat(c: Color, unshaded := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if c.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func mesh(m: Mesh, c: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(c)
	mi.position = pos
	return mi

static func sphere(r: float, c: Color) -> MeshInstance3D:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0
	return mesh(s, c)

static func box(sz: Vector3, c: Color) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = sz
	return mesh(b, c)

## Thin box; stretch it with place_beam (rope / laser / beam).
static func beam(thick: float, c: Color) -> MeshInstance3D:
	var mi := box(Vector3(thick, thick, 1.0), c)
	mi.top_level = true
	return mi

static func place_beam(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var l := a.distance_to(b)
	if l < 0.01:
		mi.visible = false
		return
	mi.visible = true
	(mi.mesh as BoxMesh).size.z = l
	var up := Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.looking_at((b - a).normalized(), up), (a + b) * 0.5)

## Scale a model so its largest dimension equals `size` metres, and centre it on its AABB.
static func fit(n: Node3D, size: float) -> void:
	var box := AABB()
	var first := true
	for node in n.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var cur: Node = m
		while cur != n and cur != null:
			xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		var bb := xf * m.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	if first:
		return
	var big := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if big <= 0.0001:
		return
	var k := size / big
	n.scale = Vector3.ONE * k
	n.position = -box.get_center() * k

## Lowest point (min y, in n's own local units) of all meshes under n. Skinned meshes use their rest AABB.
static func bottom(n: Node3D) -> float:
	var lo := 1e9
	for node in n.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var cur: Node = m
		while cur != n and cur != null:
			xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		lo = minf(lo, (xf * m.get_aabb()).position.y)
	return 0.0 if lo > 1e8 else lo

## merged AABB of all meshes under n, in n's own frame
static func aabb_of(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in n.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var cur: Node = m
		while cur != n and cur != null:
			xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		var bb := xf * m.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	return box

## Make every surface of a model see-through (alpha a), unshaded; used for the energy bubble so the player stays visible inside it.
static func translucent(n: Node, a: float) -> void:
	for node in n.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			var sm: StandardMaterial3D = (m.duplicate() if m is StandardMaterial3D else StandardMaterial3D.new())
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sm.albedo_color = Color(sm.albedo_color.r, sm.albedo_color.g, sm.albedo_color.b, a)
			sm.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.set_surface_override_material(i, sm)

static var _burst_mesh: SphereMesh
static var _burst_mat: StandardMaterial3D

## One-shot GPU particle burst (small counts, no custom shaders). colors: Array of Color, picked per particle through a random-initial-colour ramp. Frees itself.
static func burst(parent: Node, pos: Vector3, colors: Array, count: int, speed: float, size: float, life: float, gravity := 3.0) -> GPUParticles3D:
	if parent == null or not parent.is_inside_tree() or DisplayServer.get_name() == "headless":
		return null
	if _burst_mesh == null:
		_burst_mesh = SphereMesh.new()
		_burst_mesh.radial_segments = 6
		_burst_mesh.rings = 3
		_burst_mesh.radius = 0.5
		_burst_mesh.height = 1.0
		_burst_mat = StandardMaterial3D.new()
		_burst_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_burst_mat.vertex_color_use_as_albedo = true
		_burst_mesh.material = _burst_mat
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offs.append(float(i) / maxf(colors.size() - 1, 1))
		cols.append(colors[i])
	g.offsets = offs
	g.colors = cols
	var gt := GradientTexture1D.new()
	gt.gradient = g
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -gravity, 0)
	pm.scale_min = size * 0.6
	pm.scale_max = size * 1.4
	pm.scale_curve = _shrink_curve()
	pm.color_initial_ramp = gt
	var p := GPUParticles3D.new()
	p.process_material = pm
	p.draw_pass_1 = _burst_mesh
	p.amount = count
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = true
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	parent.add_child(p)
	p.global_position = pos
	parent.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)
	return p

static func _shrink_curve() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = c
	return ct
