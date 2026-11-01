class_name Bubble
extends Node3D
## Projectile. Exists on all peers (visual); only the server instance does hit detection.
var velocity := Vector3.ZERO
var weapon: WeaponData
var shooter := 0
var team := 0
var life := 0.0
var authoritative := false
var world: Node  # World
var dmg := 0

func setup(w: WeaponData, shooter_id: int, shooter_team: int, origin: Vector3, dir: Vector3, damage := -1) -> void:
	weapon = w
	dmg = w.damage if damage < 0 else damage
	shooter = shooter_id
	team = shooter_team
	position = origin
	velocity = dir.normalized() * w.projectile_speed
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = w.projectile_radius
	sm.height = w.projectile_radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	var c: Color = Config.TEAM_COLORS[shooter_team]
	mat.albedo_color = Color(c.r, c.g, c.b, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.rim_enabled = true
	mi.material_override = mat
	add_child(mi)
	if w.id == &"rocket":
		mi.visible = false
		var rk := Fx.model("ase/n1/rocket.glb")
		if rk:
			Fx.fit(rk, 0.9)
			var h := Node3D.new()
			h.basis = Basis.looking_at(-dir.normalized(), Vector3.UP)
			h.add_child(rk)
			add_child(h)
		else:
			mi.visible = true
	elif w.id == &"baseball":
		mat.albedo_color = Color(1, 1, 1, 1)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	elif w.id == &"water_gun":
		mat.albedo_color = Color(0.3, 0.7, 1.0, 0.5)
	elif w.id == &"mega_burp":
		mat.albedo_color = Color(0.9, 0.8, 0.2, 0.55)

func _physics_process(delta: float) -> void:
	life += delta
	if life > weapon.lifetime:
		queue_free()
		return
	velocity.y -= weapon.gravity * delta
	var from := position
	var to := from + velocity * delta
	var hit_world := false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var r := space.intersect_ray(q)
	if r:
		to = r.position
		hit_world = true
	if authoritative:
		var victim: int = world.bubble_test_players(from, to, weapon.projectile_radius, shooter, team)
		if victim != 0:
			world.srv_hit(victim, shooter, dmg, weapon, int(String(name).substr(1)), to)
			queue_free()
			return
	position = to
	if hit_world:
		var c: Color = Config.TEAM_COLORS[team]
		Fx.burst(get_parent(), to, [Color(c.r, c.g, c.b), Color.WHITE], 8, 2.2, 0.05, 0.35, 2.0)   # bubble pop
		queue_free()
