class_name WeaponModel
extends RefCounted
## Procedural held-weapon / gadget meshes (metres). Frame: origin = the grip (centre of the palm), barrel / long axis along -Z, up = +Y.
## Built from primitives with lit toy-plastic materials; no imported art is needed (Neutron 2 weapon models are not in the export).

static func _mat(c: Color, metal := 0.0, rough := 0.45, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m

## cylinder along -Z from z0 (rear) to z1 (front); radii at the rear / front end
static func tube(parent: Node3D, z0: float, z1: float, r0: float, r1: float, c: Color, metal := 0.0, y := 0.0, x := 0.0, emit := 0.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r1
	cm.bottom_radius = r0
	cm.height = absf(z1 - z0)
	cm.radial_segments = 20
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = _mat(c, metal, 0.4, emit)
	mi.rotation.x = -PI / 2.0   # cylinder +Y (top) -> -Z (front)
	mi.position = Vector3(x, y, (z0 + z1) * 0.5)
	parent.add_child(mi)
	return mi

static func ball(parent: Node3D, pos: Vector3, r: float, c: Color, metal := 0.0, emit := 0.0, squash := Vector3.ONE) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 20
	sm.rings = 10
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = _mat(c, metal, 0.35, emit)
	mi.position = pos
	mi.scale = squash
	parent.add_child(mi)
	return mi

static func block(parent: Node3D, pos: Vector3, size: Vector3, c: Color, metal := 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = _mat(c, metal, 0.5)
	mi.position = pos
	parent.add_child(mi)
	return mi

static func ring(parent: Node3D, z: float, r: float, thick: float, c: Color, y := 0.0, emit := 0.0) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(0.001, r - thick)
	tm.outer_radius = r
	tm.rings = 20
	tm.ring_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	mi.material_override = _mat(c, 0.2, 0.35, emit)
	mi.rotation.x = PI / 2.0   # torus axis +Y -> Z
	mi.position = Vector3(0, y, z)
	parent.add_child(mi)
	return mi

static func _grip(n: Node3D, c: Color) -> void:
	var g := block(n, Vector3(0, -0.035, 0.02), Vector3(0.05, 0.12, 0.06), c)
	g.rotation.x = 0.2
	block(n, Vector3(0, -0.075, -0.045), Vector3(0.012, 0.012, 0.04), Color(0.15, 0.15, 0.18))   # trigger guard bit

static func build(id: StringName) -> Node3D:
	var n := Node3D.new()
	match id:
		&"burp_gun":   # stubby orange blunderbuss with a flared muzzle and two side vents
			_grip(n, Color(0.2, 0.2, 0.25))
			tube(n, 0.08, -0.12, 0.05, 0.06, Color(0.95, 0.5, 0.1), 0.3)
			tube(n, -0.12, -0.27, 0.06, 0.12, Color(0.85, 0.4, 0.08), 0.3)
			tube(n, -0.265, -0.275, 0.115, 0.115, Color(0.1, 0.1, 0.12), 0.2)
			ball(n, Vector3(0, 0.07, 0.0), 0.05, Color(0.4, 0.9, 0.3))
			for sx in [-1.0, 1.0]:
				tube(n, -0.02, -0.17, 0.016, 0.016, Color(0.75, 0.75, 0.8), 0.7, 0.0, 0.075 * sx)
		&"water_gun":   # long green nozzle with a translucent water tank on top
			_grip(n, Color(0.12, 0.45, 0.2))
			tube(n, 0.1, -0.3, 0.032, 0.032, Color(0.2, 0.8, 0.35), 0.3)
			tube(n, -0.3, -0.38, 0.032, 0.02, Color(0.9, 0.9, 0.95), 0.6)
			block(n, Vector3(0, 0.005, 0.02), Vector3(0.07, 0.07, 0.2), Color(0.15, 0.6, 0.28))
			tube(n, 0.1, -0.12, 0.06, 0.06, Color(0.4, 0.8, 1.0, 0.55), 0.0, 0.085)
			ball(n, Vector3(0, 0.085, 0.1), 0.06, Color(0.4, 0.8, 1.0, 0.55))
			ball(n, Vector3(0, 0.085, -0.12), 0.06, Color(0.4, 0.8, 1.0, 0.55))
		&"mega_burp":   # big red cannon, gold bands, front-loaded
			_grip(n, Color(0.25, 0.08, 0.08))
			tube(n, 0.14, -0.2, 0.09, 0.1, Color(0.85, 0.15, 0.15), 0.4)
			tube(n, -0.2, -0.42, 0.1, 0.15, Color(0.7, 0.1, 0.1), 0.4)
			tube(n, -0.41, -0.43, 0.145, 0.145, Color(0.05, 0.05, 0.06), 0.2)
			for z in [-0.06, -0.24, -0.36]:
				ring(n, z, 0.115 + (0.02 if z < -0.2 else 0.0), 0.012, Color(0.95, 0.75, 0.2), 0.0)
			tube(n, 0.1, -0.1, 0.045, 0.045, Color(0.95, 0.75, 0.2), 0.6, 0.12)
		&"baseball":   # white launcher tube, red stripes, a ball in the feed hopper
			_grip(n, Color(0.2, 0.2, 0.25))
			tube(n, 0.1, -0.34, 0.07, 0.07, Color(0.95, 0.95, 0.95), 0.1)
			ring(n, -0.33, 0.075, 0.015, Color(0.85, 0.1, 0.1))
			ring(n, -0.02, 0.075, 0.015, Color(0.85, 0.1, 0.1))
			tube(n, -0.34, -0.37, 0.06, 0.08, Color(0.15, 0.15, 0.2), 0.3)
			tube(n, 0.0, -0.1, 0.04, 0.05, Color(0.3, 0.3, 0.35), 0.5, 0.1)
			ball(n, Vector3(0, 0.17, -0.05), 0.05, Color(1, 1, 1))
			ring(n, -0.05, 0.05, 0.006, Color(0.85, 0.1, 0.1), 0.17)
		&"rocket":   # shoulder tube (rocket-ship ultimate; the hand model is hidden while flying, kept for completeness)
			tube(n, 0.2, -0.3, 0.07, 0.07, Color(0.3, 0.35, 0.4), 0.5)
			ball(n, Vector3(0, 0, -0.3), 0.07, Color(0.85, 0.2, 0.15))
		_:   # bubble gun: cyan toy blaster, wand ring at the muzzle, pink bubble reservoir
			_grip(n, Color(0.95, 0.95, 1.0))
			tube(n, 0.1, -0.2, 0.04, 0.04, Color(0.25, 0.75, 0.95), 0.3)
			block(n, Vector3(0, 0.02, 0.0), Vector3(0.075, 0.07, 0.17), Color(0.2, 0.6, 0.9))
			tube(n, -0.2, -0.25, 0.04, 0.055, Color(0.95, 0.95, 1.0), 0.4)
			ring(n, -0.27, 0.06, 0.012, Color(1.0, 0.45, 0.8), 0.0, 0.4)
			ball(n, Vector3(0, 0.095, 0.0), 0.055, Color(1.0, 0.55, 0.85, 0.8), 0.0, 0.3)
	return n

## Goddard drone: grey ellipsoid body, cyan eye, three rotor discs.
static func drone() -> Node3D:
	var n := Node3D.new()
	ball(n, Vector3.ZERO, 0.16, Color(0.75, 0.78, 0.85), 0.6, 0.0, Vector3(1.0, 0.75, 1.15))
	ball(n, Vector3(0, 0.02, -0.15), 0.05, Color(0.2, 0.95, 1.0), 0.0, 2.0)
	for i in 3:
		var a := TAU * i / 3.0
		var arm := tube(n, 0.0, -0.2, 0.01, 0.01, Color(0.4, 0.4, 0.45), 0.6)
		arm.mesh.height = 0.22
		arm.rotation = Vector3(0, -a, PI / 2.0)
		arm.position = Vector3(cos(a), 0.0, sin(a)) * 0.11 + Vector3(0, 0.1, 0)
		var disc := tube(n, 0.0, -0.01, 0.1, 0.1, Color(0.6, 0.9, 1.0, 0.35))
		disc.mesh.height = 0.008
		disc.rotation = Vector3.ZERO
		disc.position = Vector3(cos(a), 0.0, sin(a)) * 0.22 + Vector3(0, 0.15, 0)
	return n

## Laser-trap emitter post (stands on the floor, top at y = h).
static func pylon(h: float, c: Color) -> Node3D:
	var n := Node3D.new()
	var base := tube(n, 0.0, -0.1, 0.07, 0.05, Color(0.2, 0.22, 0.28), 0.5)
	base.mesh.height = h
	base.rotation = Vector3.ZERO
	base.position = Vector3(0, h * 0.5, 0)
	ball(n, Vector3(0, h, 0), 0.07, c, 0.0, 2.5)
	return n
