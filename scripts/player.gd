class_name Player
extends CharacterBody3D
## One player. Owner (multiplayer authority) simulates + reports state; everyone else interpolates.
const RUN_SPEED := 6.0
const JUMP_SPEED := 6.5
const GRAVITY := 20.0
const MODEL_HEIGHT := 1.4
const MODEL_YAW := PI          # models face +Z; Godot forward is -Z (calibrated in shots)
const SYNC_HZ := 20.0
const MOUSE_SENS := 0.0025
const STICK_SENS := 2.8

var peer_id := 0
var team := 0
var hp := Config.MAX_HP
var alive := true
var weapon: WeaponData = WeaponData.get_weapon(&"bubble_gun")
# --- loadout (replicated by the server via World.c_loadout)
var loadout := Loadout.default_loadout()
var pending_loadout := {}      # owner only: queued choice, applies on next respawn
var max_hp := Config.MAX_HP
var gadget: GadgetData = GadgetData.get_gadget(&"energy_shield")
var movement: MovementData = MovementData.get_movement(&"sprint")
var ultimate: UltimateData = UltimateData.get_ultimate(&"rocket_ship")
var status := {}               # kind -> seconds left (server announces via c_status)
var status_val := {}           # kind -> value (shield hp, slow factor, marking team)
var ult_charge := 0
var gadget_cd := 0.0           # owner HUD estimate (server is authoritative)
var fuel := 100.0
var jumps_used := 0
var hook_point := Vector3.ZERO
var hook_t := 0.0
var hook_cd := 0.0
var mv_flags := 0              # synced: 1 jetpack, 2 glide, 4 float, 8 hook, 16 sprint
var t_flags := 0
var t_aux := Vector3.ZERO
var charge := 0.0              # owner: weapon charge 0..1
var input_blocked := false     # loadout menu open
var gadget_delay := -1.0
var pad_combo_prev := false
var base_scale := 1.0
var gear: Node3D
var fx_jet: Node3D
var fx_shield: Node3D
var fx_ship: Node3D
var fx_drone: Node3D
var fx_mark: Label3D
var fx_hook: Node3D
var fx_rope: MeshInstance3D
var cur_shrink := 1.0
var is_local := false
var world: Node  # World

var model: Node3D
var anim: AnimationPlayer
var anim_idle := ""
var anim_run := ""
var cur_anim := ""
var model_yaw := 0.0
var fire_cd := 0.0
var shoot_pose := 0.0
var sync_t := 0.0
var h_speed := 0.0
# puppet targets
var t_pos := Vector3.ZERO
var t_yaw := 0.0
var t_speed := 0.0
# camera (local only)
var cam_pivot: Node3D
var cam_arm: SpringArm3D
var cam: Camera3D
var cam_yaw := 0.0
var cam_pitch := -0.15
var label: Label3D
# test hook
var test_move := Vector2.ZERO

func _ready() -> void:
	is_local = peer_id == multiplayer.get_unique_id()
	set_multiplayer_authority(peer_id)
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = MODEL_HEIGHT
	cs.shape = cap
	cs.position.y = MODEL_HEIGHT * 0.5
	add_child(cs)
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(55)
	_build_model()
	label = Label3D.new()
	label.text = "%s %d" % [Config.TEAM_NAMES[team], peer_id]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Config.TEAM_COLORS[team]
	label.position.y = MODEL_HEIGHT + 0.25
	label.pixel_size = 0.004
	label.no_depth_test = true
	label.visible = not is_local
	add_child(label)
	t_pos = position
	fx_mark = Label3D.new()
	fx_mark.text = "V"
	fx_mark.modulate = Color(1, 0.15, 0.15)
	fx_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fx_mark.no_depth_test = true
	fx_mark.pixel_size = 0.012
	fx_mark.position.y = MODEL_HEIGHT + 0.6
	fx_mark.visible = false
	fx_mark.render_priority = 5
	add_child(fx_mark)
	set_loadout(loadout, max_hp)
	if is_local:
		_build_camera()

func _build_model() -> void:
	var rel := "jimmy.glb" if team == Config.TEAM_JIMMY else "nummey_villain.glb"
	model = Assets.load_scene(rel) as Node3D
	if model == null:
		model = MeshInstance3D.new()
		(model as MeshInstance3D).mesh = CapsuleMesh.new()
	var s := Config.WORLD_SCALE
	base_scale = s
	model.scale = Vector3.ONE * s
	add_child(model)
	anim = model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim == null:
		return
	if team == Config.TEAM_JIMMY:
		anim_idle = "jimmyidle"; anim_run = "jimmyfullrun"
	else:
		# villain model + run/stop animations from nummey.glb (same skeleton)
		var other := Assets.load_scene("nummey.glb")
		var oap := other.get_node_or_null("AnimationPlayer") as AnimationPlayer
		var lib := anim.get_animation_library("")
		if oap:
			for n in ["nummeyrun", "nummeystop"]:
				if oap.has_animation(n) and not lib.has_animation(n):
					lib.add_animation(n, oap.get_animation(n).duplicate())
		other.free()
		anim_idle = "nummeystop"; anim_run = "nummeyrun"
	for n in anim.get_animation_list():
		anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_play(anim_idle)

func _play(n: String, spd := 1.0) -> void:
	if anim == null or not anim.has_animation(n):
		return
	if cur_anim != n:
		cur_anim = n
		anim.play(n, 0.15)
	anim.speed_scale = spd

func _build_camera() -> void:
	cam_pivot = Node3D.new()
	cam_pivot.top_level = true
	add_child(cam_pivot)
	cam_arm = SpringArm3D.new()
	cam_arm.spring_length = 3.4
	cam_arm.margin = 0.15
	cam_arm.collision_mask = 1
	var sh := SphereShape3D.new(); sh.radius = 0.2
	cam_arm.shape = sh
	cam_pivot.add_child(cam_arm)
	cam = Camera3D.new()
	cam.near = 0.05
	cam.far = 1500.0
	cam.fov = 70.0
	cam.h_offset = 0.55
	cam_arm.add_child(cam)
	cam.current = true
	cam_yaw = rotation.y
	_update_cam()

func _update_cam() -> void:
	cam_pivot.global_position = global_position + Vector3(0, 1.45, 0)
	cam_pivot.rotation = Vector3(cam_pitch, cam_yaw, 0)

func _input(event: InputEvent) -> void:
	if not is_local or Config.test_mode:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= event.relative.x * MOUSE_SENS
		cam_pitch = clampf(cam_pitch - event.relative.y * MOUSE_SENS, -1.3, 1.0)

func _physics_process(delta: float) -> void:
	fire_cd = maxf(0.0, fire_cd - delta)
	gadget_cd = maxf(0.0, gadget_cd - delta)
	hook_cd = maxf(0.0, hook_cd - delta)
	for k in status.keys():
		status[k] -= delta
		if status[k] <= 0.0:
			status.erase(k)
	shoot_pose = maxf(0.0, shoot_pose - delta)
	if is_local:
		_local_step(delta)
	else:
		position = position.lerp(t_pos, 1.0 - exp(-16.0 * delta))
		model_yaw = lerp_angle(model_yaw, t_yaw, 1.0 - exp(-16.0 * delta))
		h_speed = t_speed
	_animate()

func has_status(kind: String) -> bool:
	return status.get(kind, 0.0) > 0.0

func set_status(kind: String, dur: float, val: float = 0.0) -> void:
	status[kind] = dur
	status_val[kind] = val

func effective_weapon() -> WeaponData:
	if has_status("ult") and ultimate.p.has("weapon"):
		return WeaponData.get_weapon(ultimate.p.weapon)
	return weapon

func ult_is(uid: StringName) -> bool:
	return has_status("ult") and ultimate.id == uid

func speed_mult(sprinting: bool) -> float:
	var m := 1.0
	if sprinting and movement.id == &"sprint":
		m *= movement.f("speed_mult", 1.0)
	if has_status("shrink"):
		m *= GadgetData.get_gadget(&"shrink_ray").f("slow", 1.0)
	if has_status("slow"):
		m *= float(status_val.get("slow", 1.0))
	if ult_is(&"goddard_jeep"):
		m *= ultimate.f("speed_mult", 1.0)
	return m

func _pad_combo() -> bool:
	for d in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(d, JOY_BUTTON_LEFT_SHOULDER) and Input.is_joy_button_pressed(d, JOY_BUTTON_RIGHT_SHOULDER):
			return true
	return false

## Gadget / ultimate button handling (owner only).
func _gear_input(delta: float) -> void:
	var combo := _pad_combo()
	if Input.is_action_just_pressed("ultimate") or (combo and not pad_combo_prev):
		gadget_delay = -1.0
		try_ultimate()
	elif Input.is_action_just_pressed("gadget"):
		gadget_delay = 0.07   # lets LB+RB register as the ultimate instead
	if gadget_delay >= 0.0:
		gadget_delay -= delta
		if gadget_delay < 0.0:
			gadget_delay = -1.0
			if not combo:
				try_gadget()
	pad_combo_prev = combo

func try_gadget(dir_override := Vector3.ZERO) -> void:
	if not alive or gadget_cd > 0.0 or has_status("phase"):
		return
	if dir_override == Vector3.ZERO and cam == null:
		return
	gadget_cd = gadget.f("cooldown")
	world.request_gadget(muzzle(), dir_override if dir_override != Vector3.ZERO else aim_direction_from_camera())

func try_ultimate() -> void:
	if alive and ult_charge >= int(ultimate.f("cost")) and not has_status("ult"):
		world.request_ultimate()

func _local_step(delta: float) -> void:
	var dead_or_over: bool = (not alive) or world.match_over
	var live_input := (not Config.test_mode) and (not dead_or_over) and not input_blocked
	var mv := Vector2.ZERO
	var firing := false
	var jump_pressed := false
	var jump_held := false
	var mvt_pressed := false
	var mvt_held := false
	if Config.test_mode:
		mv = test_move
	elif live_input:
		mv = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		firing = Input.is_action_pressed("fire")
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		cam_yaw -= look.x * STICK_SENS * delta
		cam_pitch = clampf(cam_pitch - look.y * STICK_SENS * delta, -1.3, 1.0)
		jump_pressed = Input.is_action_just_pressed("jump")
		jump_held = Input.is_action_pressed("jump")
		mvt_pressed = Input.is_action_just_pressed("movement")
		mvt_held = Input.is_action_pressed("movement")
		_gear_input(delta)
	if not alive:
		mv = Vector2.ZERO
	var flags := 0
	var floor_now := is_on_floor()
	var dir := Basis(Vector3.UP, cam_yaw) * Vector3(mv.x, 0, mv.y)
	var sprinting := mvt_held and mv.length() > 0.1
	var spd := RUN_SPEED * speed_mult(sprinting)
	if sprinting and movement.id == &"sprint":
		flags |= 16
	if alive and ult_is(&"rocket_ship"):
		# simplified rocket ship: free flight along the camera
		var fb := Basis.from_euler(Vector3(cam_pitch, cam_yaw, 0))
		velocity = velocity.lerp(fb * Vector3(mv.x, 0, mv.y) * ultimate.f("fly_speed", 13.0), 1.0 - exp(-6.0 * delta))
		hook_t = 0.0
	elif hook_t > 0.0 and alive:
		var to := hook_point - (global_position + Vector3(0, 1.0, 0))
		hook_t -= delta
		if to.length() < 1.6 or hook_t <= 0.0 or (live_input and not mvt_held):
			hook_t = 0.0
			hook_cd = movement.f("cooldown", 2.5)
		else:
			velocity = to.normalized() * movement.f("speed", 26.0)
			flags |= 8
	else:
		if floor_now:
			jumps_used = 0
			velocity.x = dir.x * spd
			velocity.z = dir.z * spd
			if alive and jump_pressed:
				velocity.y = JUMP_SPEED
		else:
			velocity.x = move_toward(velocity.x, dir.x * spd, 20.0 * delta)
			velocity.z = move_toward(velocity.z, dir.z * spd, 20.0 * delta)
		velocity.y -= GRAVITY * delta
		if alive and live_input:
			match movement.id:
				&"goof_boots":
					if not floor_now and jump_pressed and jumps_used < int(movement.f("extra_jumps")):
						velocity.y = JUMP_SPEED
						jumps_used += 1
					elif not floor_now and jump_held and velocity.y < -movement.f("glide_fall"):
						velocity.y = -movement.f("glide_fall")
						flags |= 2
				&"jetpack":
					if (mvt_held or (jump_held and not floor_now)) and fuel > 0.5:
						velocity.y = minf(velocity.y + movement.f("thrust") * delta, movement.f("max_up"))
						fuel = maxf(0.0, fuel - movement.f("drain") * delta)
						flags |= 1
				&"bubble_float":
					if mvt_held and fuel > 0.5 and velocity.y < -movement.f("fall"):
						velocity.y = -movement.f("fall")
						fuel = maxf(0.0, fuel - movement.f("drain") * delta)
						flags |= 4
				&"grapple":
					if mvt_pressed and hook_cd <= 0.0 and cam != null:
						var from := cam.global_position
						var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * movement.f("range"), 1)
						var r := get_world_3d().direct_space_state.intersect_ray(q)
						if r:
							hook_point = r.position
							hook_t = movement.f("max_time")
	if floor_now and (flags & 5) == 0:
		fuel = minf(movement.f("fuel", 100.0), fuel + movement.f("regen") * delta)
	mv_flags = flags
	move_and_slide()
	h_speed = Vector2(velocity.x, velocity.z).length()
	if global_position.y < -40.0:  # fell out of the world
		var sp: Transform3D = world.level.spawn_point(team, 0)
		global_position = sp.origin
		velocity = Vector3.ZERO
	if dir.length() > 0.1:
		var target := atan2(-dir.x, -dir.z)
		model_yaw = lerp_angle(model_yaw, target, 1.0 - exp(-14.0 * delta))
	if shoot_pose > 0.0 or ult_is(&"rocket_ship"):
		model_yaw = lerp_angle(model_yaw, cam_yaw, 1.0 - exp(-20.0 * delta))
	var w := effective_weapon()
	if alive and not has_status("phase") and not world.match_over:
		if w.charge_time > 0.0:
			if firing:
				if fire_cd <= 0.0:
					charge = minf(1.0, charge + delta / w.charge_time)
			elif charge > 0.0:
				if charge >= 0.1:
					fire(aim_direction_from_camera(), charge)
				charge = 0.0
		else:
			charge = 0.0
			if firing and fire_cd <= 0.0:
				fire(aim_direction_from_camera())
	else:
		charge = 0.0
	_update_cam()
	sync_t += delta
	if sync_t >= 1.0 / SYNC_HZ:
		sync_t = 0.0
		if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			net_state.rpc(global_position, model_yaw, h_speed, mv_flags, hook_point if hook_t > 0.0 else Vector3.ZERO)


func muzzle() -> Vector3:
	return global_position + Vector3(0, 1.0, 0)

func aim_direction_from_camera() -> Vector3:
	var from := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 120.0, 1)
	var r := space.intersect_ray(q)
	var target: Vector3 = r.position if r else from + fwd * 120.0
	var origin := muzzle() + Vector3(0, 0, 0)
	return (target - origin).normalized()

## Owner-side fire request (server validates). Used by input and by tests.
func fire(dir: Vector3, chg := 0.0) -> void:
	var w := effective_weapon()
	if fire_cd > 0.0 or has_status("phase"):
		return
	fire_cd = w.fire_interval
	shoot_pose = 0.4
	world.request_fire_local(muzzle() + dir.normalized() * 0.5, dir, chg)

@rpc("authority", "unreliable_ordered")
func net_state(pos: Vector3, yaw: float, spd: float, flags := 0, aux := Vector3.ZERO) -> void:
	t_pos = pos
	t_yaw = yaw
	t_speed = spd
	t_flags = flags
	t_aux = aux

func eff_flags() -> int:
	return mv_flags if is_local else t_flags

func _animate() -> void:
	var dt := get_physics_process_delta_time()
	var shr := 0.5 if has_status("shrink") else 1.0
	cur_shrink = lerpf(cur_shrink, shr, 1.0 - exp(-10.0 * dt))
	if model:
		model.rotation.y = model_yaw + MODEL_YAW
		model.visible = alive and not ult_is(&"rocket_ship") and not ult_is(&"goddard_jeep")
		model.scale = Vector3.ONE * base_scale * cur_shrink
	if gear:
		gear.rotation.y = model_yaw
		gear.scale = Vector3.ONE * cur_shrink
		gear.visible = alive
	_update_fx()
	if label:
		label.visible = alive and not is_local
	if h_speed > 0.4:
		_play(anim_run, clampf(h_speed / RUN_SPEED, 0.6, 1.4))
	else:
		_play(anim_idle, 1.0)

func _set_ghost(on: bool) -> void:
	if model == null:
		return
	for mi in model.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).transparency = 0.65 if on else 0.0

var _ghost := false
func _update_fx() -> void:
	var fl := eff_flags()
	var ph := has_status("phase")
	if ph != _ghost:
		_ghost = ph
		_set_ghost(ph)
	if fx_jet:
		fx_jet.visible = (fl & 1) != 0 and alive
	if fx_shield:
		fx_shield.visible = alive and (has_status("shield") or (fl & 4) != 0)
		var m := fx_shield as MeshInstance3D
		if m and m.material_override:
			(m.material_override as StandardMaterial3D).albedo_color = Color(0.4, 1.0, 0.6, 0.28) if (fl & 4) != 0 and not has_status("shield") else Color(0.3, 0.7, 1.0, 0.3)
	if fx_ship:
		fx_ship.visible = alive and (ult_is(&"rocket_ship") or ult_is(&"goddard_jeep"))
	if fx_drone:
		fx_drone.visible = alive and has_status("drone")
		fx_drone.position = Vector3(cos(Time.get_ticks_msec() / 400.0) * 0.8, 2.0 + sin(Time.get_ticks_msec() / 300.0) * 0.1, sin(Time.get_ticks_msec() / 400.0) * 0.8)
	if fx_mark:
		var lt: int = world.local_team() if world else -1
		fx_mark.visible = alive and has_status("marked") and int(status_val.get("marked", -1)) == lt and not is_local
	var hooking := (fl & 8) != 0 and alive
	var hp_pt := hook_point if is_local else t_aux
	if fx_hook:
		fx_hook.visible = hooking
		if hooking:
			fx_hook.global_position = hp_pt
	if fx_rope:
		if hooking:
			Fx.place_beam(fx_rope, muzzle(), hp_pt)
		else:
			fx_rope.visible = false

func set_dead() -> void:
	alive = false
	collision_layer = 0
	status.clear()
	hook_t = 0.0
	if not is_local:
		t_speed = 0.0

func set_alive_at(t: Transform3D) -> void:
	alive = true
	hp = max_hp
	status.clear()
	hook_t = 0.0
	gadget_cd = 0.0
	fuel = movement.f("fuel", 100.0)
	collision_layer = 2
	if is_local:
		global_position = t.origin
		velocity = Vector3.ZERO
		cam_yaw = t.basis.get_euler().y
		model_yaw = cam_yaw
	else:
		global_position = t.origin
		t_pos = t.origin

## Applies a server-confirmed loadout (also builds the gear visuals).
func set_loadout(lo: Dictionary, mhp: int) -> void:
	loadout = Loadout.sanitize(lo)
	max_hp = mhp
	weapon = WeaponData.get_weapon(loadout.primary)
	gadget = GadgetData.get_gadget(loadout.gadget)
	movement = MovementData.get_movement(loadout.movement)
	ultimate = UltimateData.get_ultimate(loadout.ultimate)
	fuel = movement.f("fuel", 100.0)
	if is_inside_tree():
		_build_gear()

func _build_gear() -> void:
	if gear:
		gear.queue_free()
	if fx_hook:
		fx_hook.queue_free(); fx_hook = null
	if fx_rope:
		fx_rope.queue_free(); fx_rope = null
	gear = Node3D.new()
	add_child(gear)
	fx_jet = null; fx_shield = null; fx_ship = null; fx_drone = null
	# held weapon placeholder (Neutron 2 Granny weapon models are not exported yet)
	var gun := Node3D.new()
	gun.position = Vector3(0.28, 0.95, -0.35)
	match weapon.id:
		&"burp_gun":
			gun.add_child(Fx.box(Vector3(0.18, 0.18, 0.4), Color(1.0, 0.55, 0.1)))
		&"water_gun":
			gun.add_child(Fx.box(Vector3(0.08, 0.1, 0.55), Color(0.2, 0.85, 0.35)))
		&"mega_burp":
			gun.add_child(Fx.box(Vector3(0.3, 0.3, 0.6), Color(0.9, 0.2, 0.2)))
		&"baseball":
			gun.add_child(Fx.box(Vector3(0.2, 0.2, 0.55), Color(0.95, 0.95, 0.95)))
		_:
			gun.add_child(Fx.box(Vector3(0.12, 0.14, 0.4), Color(0.3, 0.8, 1.0)))
	gear.add_child(gun)
	match movement.id:
		&"jetpack":
			var jp := Fx.model("ase/n2/jetpack01.glb")
			var holder := Node3D.new()
			holder.position = Vector3(0, 0.95, 0.28)
			if jp:
				Fx.fit(jp, 0.55)
				holder.add_child(jp)
			else:
				holder.add_child(Fx.box(Vector3(0.3, 0.5, 0.2), Color(0.6, 0.6, 0.65)))
			gear.add_child(holder)
			fx_jet = Node3D.new()
			fx_jet.position = Vector3(0, 0.55, 0.28)
			var fl := Fx.model("ase/n1/fire.glb")
			if fl:
				Fx.fit(fl, 0.6)
				fx_jet.add_child(fl)
			else:
				var cone := CylinderMesh.new(); cone.top_radius = 0.12; cone.bottom_radius = 0.0; cone.height = 0.5
				fx_jet.add_child(Fx.mesh(cone, Color(1.0, 0.6, 0.1, 0.9), Vector3(0, -0.15, 0)))
			fx_jet.visible = false
			gear.add_child(fx_jet)
		&"goof_boots":
			for sx in [-0.14, 0.14]:
				var b := Fx.model("ase/n2/goofbootfly.glb")
				var h := Node3D.new()
				h.position = Vector3(sx, 0.1, 0)
				if b:
					Fx.fit(b, 0.28)
					h.add_child(b)
				else:
					h.add_child(Fx.box(Vector3(0.14, 0.18, 0.28), Color(0.9, 0.8, 0.2)))
				gear.add_child(h)
		&"grapple":
			fx_hook = Fx.model("ase/n1/hook.glb")
			if fx_hook:
				Fx.fit(fx_hook, 0.4)
			else:
				fx_hook = Fx.sphere(0.12, Color(0.8, 0.8, 0.8))
			fx_hook.top_level = true
			fx_hook.visible = false
			add_child(fx_hook)
			fx_rope = Fx.beam(0.04, Color(0.7, 0.5, 0.25))
			fx_rope.visible = false
			add_child(fx_rope)
	# shield / float bubble
	var bub := Fx.model("ase/n2/energybubble.glb")
	if bub:
		var holder2 := Node3D.new()
		holder2.position.y = 0.75
		Fx.fit(bub, 2.1)
		holder2.add_child(bub)
		fx_shield = holder2
	else:
		var bs := Fx.sphere(1.05, Color(0.3, 0.7, 1.0, 0.3))
		bs.position.y = 0.75
		fx_shield = bs
	fx_shield.visible = false
	gear.add_child(fx_shield)
	# ultimate vehicle
	fx_ship = Node3D.new()
	fx_ship.position.y = 0.6
	if ultimate.id == &"rocket_ship":
		var sh := Fx.model("ase/n1/strato.glb")
		if sh:
			Fx.fit(sh, 3.0)
			fx_ship.add_child(sh)
		else:
			var cap := CapsuleMesh.new(); cap.radius = 0.35; cap.height = 2.2
			var mi := Fx.mesh(cap, Color(0.85, 0.85, 0.9))
			mi.rotation.x = PI / 2.0
			fx_ship.add_child(mi)
	else:
		fx_ship.add_child(Fx.box(Vector3(1.3, 0.6, 2.4), Color(0.45, 0.55, 0.25)))   # Goddard jeep placeholder
	fx_ship.visible = false
	gear.add_child(fx_ship)
	fx_drone = Fx.sphere(0.18, Color(0.9, 0.9, 0.3))
	fx_drone.visible = false
	gear.add_child(fx_drone)
