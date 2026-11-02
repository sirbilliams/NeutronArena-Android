class_name ModeView
extends Node3D
## Draws the objective of the current mode on every peer from world.mode: CTF flags (procedural stand-ins), KOTH zone ring.
## Pure visuals: all rules live in mode_ctf.gd / mode_koth.gd.
var world: World
var flags := [null, null]    # Node3D per team
var props := [null, null]    # propeller nodes (spun every frame)
var ring: MeshInstance3D
var ring_mat: StandardMaterial3D
var t := 0.0

func _ready() -> void:
	name = "ModeView"
	world.mode_changed.connect(_rebuild)
	_rebuild()

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	flags = [null, null]
	props = [null, null]
	ring = null
	var m := world.mode
	if m is ModeCtf:
		for team in 2:
			flags[team] = _make_flag(team)
			add_child(flags[team])
	elif m is ModeKoth:
		_make_ring()

static func _mat(c: Color, glow := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(c.r, c.g, c.b, alpha)
	if glow > 0.0:
		mt.emission_enabled = true
		mt.emission = c
		mt.emission_energy_multiplier = glow
	if alpha < 1.0:
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mt

static func _part(parent: Node3D, mesh: Mesh, mt: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mt
	mi.position = pos
	parent.add_child(mi)
	return mi

## TODO(goofbot model): swap the stand-ins for the imported models once the player's files provide them
## (Assets.try_scene("<rel path>")); Goddard = Jimmy's flag, goof-bot = Negatron's. Keep the Node3D contract: origin at the feet.
func _make_flag(team: int) -> Node3D:
	var root := Node3D.new()
	var col: Color = Config.TEAM_COLORS[team]
	var beam := _part(root, CylinderMesh.new(), _mat(col, 1.0, 0.25), Vector3(0, 7.0, 0))
	(beam.mesh as CylinderMesh).top_radius = 0.12; (beam.mesh as CylinderMesh).bottom_radius = 0.12; (beam.mesh as CylinderMesh).height = 14.0
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	if team == Config.TEAM_JIMMY:
		_goddard(body, col)
	else:
		props[team] = _goofbot(body, col)
	return root

func _goddard(b: Node3D, col: Color) -> void:
	var steel := _mat(Color(0.75, 0.8, 0.9), 0.2)
	var tint := _mat(col, 0.6)
	var bx := BoxMesh.new(); bx.size = Vector3(1.0, 0.5, 0.5)
	_part(b, bx, steel, Vector3(0, 0.9, 0))
	var hd := SphereMesh.new(); hd.radius = 0.28; hd.height = 0.56
	_part(b, hd, steel, Vector3(0.62, 1.2, 0))
	var sn := BoxMesh.new(); sn.size = Vector3(0.3, 0.14, 0.18)
	_part(b, sn, tint, Vector3(0.9, 1.15, 0))
	var ant := CylinderMesh.new(); ant.top_radius = 0.02; ant.bottom_radius = 0.02; ant.height = 0.4
	_part(b, ant, tint, Vector3(0.55, 1.65, 0.1))
	for lx in [-0.35, 0.35]:
		for lz in [-0.18, 0.18]:
			var lg := CylinderMesh.new(); lg.top_radius = 0.06; lg.bottom_radius = 0.06; lg.height = 0.65
			_part(b, lg, steel, Vector3(lx, 0.33, lz))

func _goofbot(b: Node3D, col: Color) -> Node3D:
	var sp := SphereMesh.new(); sp.radius = 0.45; sp.height = 0.9
	_part(b, sp, _mat(col, 0.5), Vector3(0, 1.1, 0))
	var eye := SphereMesh.new(); eye.radius = 0.1; eye.height = 0.2
	_part(b, eye, _mat(Color(1, 0.1, 0.1), 2.0), Vector3(0.38, 1.25, 0.14))
	_part(b, eye, _mat(Color(1, 0.1, 0.1), 2.0), Vector3(0.38, 1.25, -0.14))
	var st := CylinderMesh.new(); st.top_radius = 0.04; st.bottom_radius = 0.04; st.height = 0.3
	_part(b, st, _mat(Color(0.3, 0.3, 0.35)), Vector3(0, 1.7, 0))
	var prop := Node3D.new()
	prop.position = Vector3(0, 1.85, 0)
	b.add_child(prop)
	for a in 2:
		var bl := BoxMesh.new(); bl.size = Vector3(1.3, 0.04, 0.14)
		var mi := _part(prop, bl, _mat(Color(0.85, 0.85, 0.9), 0.3), Vector3.ZERO)
		mi.rotation.y = a * PI * 0.5
	return prop

func _make_ring() -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = Balance.KOTH.radius; cm.bottom_radius = Balance.KOTH.radius; cm.height = 0.15
	ring_mat = _mat(Color.WHITE, 1.0, 0.35)
	ring = _part(self, cm, ring_mat, Vector3.ZERO)

func _process(dt: float) -> void:
	t += dt
	var m := world.mode
	if m is ModeCtf:
		for team in 2:
			var f: Node3D = flags[team]
			if f == null:
				continue
			var fl: Dictionary = m.flag[team]
			var pos: Vector3 = fl.pos
			if fl.st == ModeCtf.CARRIED and world.players.has(fl.carrier):
				pos = (world.players[fl.carrier] as Node3D).global_position + Vector3(0, 1.6, 0)
				f.get_node("Body").scale = Vector3.ONE * 0.6
			else:
				f.get_node("Body").scale = Vector3.ONE
			f.global_position = pos
			(f.get_node("Body") as Node3D).position.y = 0.15 * sin(t * 2.0 + team) if team == Config.TEAM_NEGATRON else 0.0
			if props[team] != null:
				(props[team] as Node3D).rotation.y += dt * 25.0
	elif m is ModeKoth and ring != null:
		ring.global_position = m.center + Vector3(0, 0.1, 0)
		var c := Color.WHITE
		if m.holder == 0 or m.holder == 1:
			c = Config.TEAM_COLORS[m.holder]
		elif m.holder == 2:
			c = Color(1.0, 0.85, 0.2)
		ring_mat.albedo_color = Color(c.r, c.g, c.b, 0.35)
		ring_mat.emission = c
