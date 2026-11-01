class_name Player
extends CharacterBody3D
## One player. Owner (multiplayer authority) simulates + reports state; everyone else interpolates.
const RUN_SPEED := 6.0
const JUMP_SPEED := 6.5
const GRAVITY := 20.0
const MODEL_HEIGHT := 1.4
const MODEL_YAW := PI / 2.0     # glb characters actually face +X natively (shots: at PI they faced -X, 90 deg off the movement dir); PI/2 makes them face Godot forward (-Z)
const PALM_JIM := Vector3(8.4, 4.0, -1.8)   # right-hand bone space (raw model units): centre of the hand mesh
const PALM_NEG := Vector3(10.2, 3.3, -1.35)
const BOOT_OFF := Vector3(4.0, 0.0, -4.0)   # goof boot centre in the foot bone's space (raw units)
const BOOT_SIZE := 36.0
const PLATE_OFF := Vector3(14.0, -7.0, 0.0)   # chest plate centre in the spine bone's space (raw units)
const SYNC_HZ := 20.0
const MOUSE_SENS := 0.0025
const STICK_SENS := 2.8
# --- movement feel
const ACCEL_GROUND := 55.0      # m/s^2 towards the wish velocity on the floor
const DECEL_GROUND := 70.0      # m/s^2 braking when there is no input (no sliding when idle)
const ACCEL_AIR := 16.0
const DECEL_AIR := 5.0          # air drag: keep momentum when the stick is released
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.12
const JUMP_CUT := 0.45          # releasing jump while rising caps the rise speed at this fraction
const TERMINAL_FALL := 35.0
const STEP_H := 0.35            # max curb / step height walked up without jumping
const STEP_LOOK := 0.25         # m probed ahead for a step
const TURN_RATE := 16.0         # exp smoothing of facing
const MAX_TURN := 14.0          # rad/s cap on facing change (no snapping)
const LOOK_DEADZONE := 0.18
const LOOK_RAMP_TIME := 0.35    # seconds at full deflection until stick look reaches its boost
const LOOK_BOOST := 0.6
const INTERP_DELAY := 0.1       # remote players are rendered this far in the past
const WALK_ENTER := 0.25
const RUN_ENTER := 1.2
const RUN_EXIT := 1.0

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
# --- feel (strafe twist, flinch, death pop, muzzle flash)
const TW_MAX := 1.0            # rad, max leg turn away from the aim direction while strafing (torso counter-rotates)
const FLINCH_TIME := 0.2
const POP_TIME := 0.4
var feel_mod: FeelMod
var vel_h := Vector2.ZERO       # horizontal velocity estimate (x, z)
var _prev_pos := Vector3.ZERO
var strafe_t := 0.0
var strafe_on := false
var strafe_rev := false         # legs play backwards (backpedal)
var tw_cur := 0.0
var flinch_t := 0.0
var flinch_side := 0.0
var dying := 0.0                # >0 while the death pop plays
var flash: Node3D
var flash_t := 0.0
var flash_peak := 0.07
var jet_k := 0.0
var fx_shield: Node3D
var fx_ship: Node3D
var scooter_model: Node3D   # Negatron riding his own scooter (swapped in during the ultimate)
var scooter_anim: AnimationPlayer
var scooter_off := 0.0     # raw units: lifts the scooter model so its lowest point (wheels) is on the floor
var fx_gun: Node3D
var gun_ba: BoneAttachment3D
var boot_ba: Array[BoneAttachment3D] = []
var palm: Node3D
var jim_scooter: Node3D     # Goddard's scooter (scooter.glb, same frame as Jimmy's scooter anims)
var fx_boots: Node3D
var fx_sprint: Node3D
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
var anim_walk := ""
var anim_jump := ""
var anim_fall := ""
var anim_fly := ""
var vy_est := 0.0
var _last_y := 0.0
var jp_attach: BoneAttachment3D
var air_time := 0.0
var cur_anim := ""
var model_yaw := 0.0
var fire_cd := 0.0
var shoot_pose := 0.0
var sync_t := 0.0
var h_speed := 0.0
var coyote_t := 0.0
var jump_buf := 0.0
var jump_was_held := false
var vis_off := 0.0             # visual-only Y offset (m), decays to 0: hides step-up / snap pops
var lift_cur := 0.0            # current foot lift (m), blended between clips
var gait := &"idle"            # idle / walk / run / air
var floor_flicker := 0         # test: frames is_on_floor() changed while walking flat
var look_ramp := 0.0
var cam_focus := Vector3.ZERO
var cam_ready := false
var t_grounded := true
var _snaps: Array = []         # remote snapshot buffer [{t, pos, yaw, spd, flags, aux, g}]
var _clock_off := 0.0
var _clock_init := false
var _was_floor := false
var _prev_y := 0.0
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
var test_jump := false
var test_jump_held := false

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
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50)
	floor_stop_on_slope = true
	floor_constant_speed = true
	floor_block_on_wall = true
	max_slides = 6
	wall_min_slide_angle = deg_to_rad(15)
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
	if team == Config.TEAM_NEGATRON:
		scooter_model = Assets.try_scene("nummey_scooter.glb") as Node3D
		if scooter_model:
			scooter_model.scale = Vector3.ONE * s
			scooter_model.visible = false
			scooter_off = -Fx.bottom(scooter_model)
			add_child(scooter_model)
			scooter_anim = scooter_model.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if scooter_anim and scooter_anim.has_animation("nummeyscooter"):
				scooter_anim.get_animation("nummeyscooter").loop_mode = Animation.LOOP_LINEAR
	if team == Config.TEAM_JIMMY:
		jim_scooter = Assets.try_scene("scooter.glb") as Node3D
		if jim_scooter:
			jim_scooter.scale = Vector3.ONE * s
			jim_scooter.visible = false
			add_child(jim_scooter)
	anim = model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim == null:
		return
	if team == Config.TEAM_JIMMY:
		anim_idle = "jimmyidle"; anim_run = "jimmyfullrun"; anim_walk = "jimmywalk"; anim_jump = "jimmyjump"; anim_fall = "jimmyfall"; anim_fly = "jimmyfly"
	else:
		# villain model + run/stop animations from nummey.glb (same skeleton)
		var other := Assets.load_scene("nummey.glb")
		var oap := other.get_node_or_null("AnimationPlayer") as AnimationPlayer
		var lib := anim.get_animation_library("")
		if oap:
			for n in ["nummeyrun", "nummeystop", "nummeywalk"]:
				if oap.has_animation(n) and not lib.has_animation(n):
					lib.add_animation(n, oap.get_animation(n).duplicate())
		other.free()
		anim_idle = "nummeystop"; anim_run = "nummeyrun"; anim_walk = "nummeywalk"; anim_fall = ""; anim_jump = ""; anim_fly = "nummeyfly"   # numflyair is a tumble loop: not used; Negatron holds a run frame in the air
	AnimFix.fix_player(anim)
	# NOT deterministic: AnimationPlayer.deterministic made every crossfade swing the spine/head ~20 deg for the blend time then snap back (found with tools/walkprobe.gd).
	# AnimFix.fix_player gives every clip the union of all tracks (missing ones = rest pose) so un-keyed bones still fall back to rest.
	for n in anim.get_animation_list():
		anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	if anim.has_animation(anim_jump) and anim_jump == "jimmyjump":
		anim.get_animation(anim_jump).loop_mode = Animation.LOOP_NONE   # plays once, then holds the last pose
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.size() > 0:
		feel_mod = FeelMod.new()
		feel_mod.name = "FeelMod"
		sks[0].add_child(feel_mod)
	_play(anim_idle)

func _play(n: String, spd := 1.0, blend := 0.18) -> void:
	if anim == null or not anim.has_animation(n):
		return
	if cur_anim != n:
		cur_anim = n
		anim.play(n, blend)   # (seek-to-keep-phase flashed the rest pose for a frame, so plain crossfade)
	anim.speed_scale = spd

## idle / walk / run / air from horizontal speed (hysteresis so it never flaps); returns the gait
func _gait_for(hs: float, airborne: bool) -> StringName:
	if airborne:
		return &"air"
	var enter_w := WALK_ENTER if (gait == &"idle" or gait == &"air") else WALK_ENTER * 0.6
	if hs < enter_w:
		return &"idle"
	if hs > (RUN_EXIT if gait == &"run" else RUN_ENTER):
		return &"run"
	return &"walk"

func _build_camera() -> void:
	cam_pivot = Node3D.new()
	cam_pivot.top_level = true
	cam_pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # follows the interpolated body in _process
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
	_update_cam(0.0)

## Render-rate camera: follows the physics-interpolated body with slight lag (horizontal tighter than vertical).
func _update_cam(dt: float) -> void:
	var tgt := get_global_transform_interpolated().origin + Vector3(0, 1.45, 0)
	if not cam_ready or cam_focus.distance_to(tgt) > 6.0:
		cam_focus = tgt
		cam_ready = true
	else:
		var kx := 1.0 - exp(-22.0 * dt)
		var ky := 1.0 - exp(-9.0 * dt)
		cam_focus.x = lerpf(cam_focus.x, tgt.x, kx)
		cam_focus.z = lerpf(cam_focus.z, tgt.z, kx)
		cam_focus.y = lerpf(cam_focus.y, tgt.y, ky)
	cam_pivot.global_position = cam_focus
	cam_pivot.rotation = Vector3(cam_pitch, cam_yaw, 0)

func _look_input(delta: float) -> void:
	var v := Vector2(Input.get_axis("look_left", "look_right"), Input.get_axis("look_up", "look_down"))
	var m := v.length()
	if m <= LOOK_DEADZONE:
		look_ramp = maxf(0.0, look_ramp - delta / 0.12)
		return
	var shaped := pow((m - LOOK_DEADZONE) / (1.0 - LOOK_DEADZONE), 1.7)   # fine aim near the centre, fast at the rim
	if m > 0.85:
		look_ramp = minf(1.0, look_ramp + delta / LOOK_RAMP_TIME)
	else:
		look_ramp = maxf(0.0, look_ramp - delta / 0.12)
	var rate := STICK_SENS * 1.25 * shaped * (1.0 + LOOK_BOOST * look_ramp)
	var d := v / m
	cam_yaw -= d.x * rate * delta
	cam_pitch = clampf(cam_pitch - d.y * rate * 0.8 * delta, -1.3, 1.0)

func _process(delta: float) -> void:
	if is_local and cam_pivot:
		if not Config.test_mode and alive and not input_blocked and world != null and not world.match_over:
			_look_input(delta)
		_update_cam(delta)

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
		_puppet_step(delta)
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
	if ult_is(&"goddard_scooter"):
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
		jump_pressed = test_jump
		jump_held = test_jump_held
		test_jump = false
	elif live_input:
		mv = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		firing = Input.is_action_pressed("fire")
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
			coyote_t = COYOTE_TIME
		else:
			coyote_t = maxf(0.0, coyote_t - delta)
		jump_buf = JUMP_BUFFER if jump_pressed else maxf(0.0, jump_buf - delta)
		var jumped := false
		if alive and jump_buf > 0.0 and coyote_t > 0.0 and velocity.y <= 0.5:
			velocity.y = JUMP_SPEED
			coyote_t = 0.0
			jump_buf = 0.0
			jumped = true
		var grounded := floor_now and not jumped
		# acceleration curves: snappy on the ground, floaty-but-controllable in the air, hard brake when idle
		var wish := Vector2(dir.x * spd, dir.z * spd)
		var cur := Vector2(velocity.x, velocity.z)
		var has_input := dir.length() > 0.05
		var rate: float
		if grounded:
			rate = ACCEL_GROUND if has_input else DECEL_GROUND
			if has_input and cur.dot(wish) < 0.0:
				rate *= 1.6    # reversing
		else:
			rate = ACCEL_AIR if has_input else DECEL_AIR
		cur = cur.move_toward(wish, rate * delta)
		velocity.x = cur.x
		velocity.z = cur.y
		if grounded:
			velocity.y = 0.0   # floor snap keeps contact; no gravity build-up and no residual slope velocity => no micro-bounce
		else:
			velocity.y = maxf(velocity.y - GRAVITY * delta * 0.5, -TERMINAL_FALL)   # half step now, half after the move: tick-rate independent arcs
		if jump_was_held and not jump_held and velocity.y > JUMP_SPEED * JUMP_CUT and movement.id != &"jetpack" and not jumped:
			velocity.y = JUMP_SPEED * JUMP_CUT   # short hop on early release
		jump_was_held = jump_held
		if grounded and alive and not hook_active_now():
			_try_step_up(delta)
		if alive and live_input:
			match movement.id:
				&"goof_boots":
					if not floor_now and coyote_t <= 0.0 and not jumped and jump_pressed and jumps_used < int(movement.f("extra_jumps")):
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
	var y0 := global_position.y
	var p0 := global_position
	move_and_slide()
	var on_f := is_on_floor()
	if on_f != _was_floor:
		floor_changes += 1
	# a floor-snap drop (curb edge) pops the body down: keep the model where it was and ease it down
	var hmove := Vector2(global_position.x - p0.x, global_position.z - p0.z).length()
	var dy := global_position.y - y0
	if _was_floor and on_f and dy < -(0.9 * hmove + 0.04):
		vis_off = minf(0.4, vis_off - dy)
	_was_floor = on_f
	if not on_f:
		velocity.y = maxf(velocity.y - GRAVITY * delta * 0.5, -TERMINAL_FALL)
	h_speed = Vector2(velocity.x, velocity.z).length()
	if global_position.y < -40.0:  # fell out of the world
		var sp: Transform3D = world.level.spawn_point(team, 0)
		global_position = sp.origin
		velocity = Vector3.ZERO
	if shoot_pose > 0.0 or ult_is(&"rocket_ship"):
		_face(cam_yaw, delta, 1.3)    # aiming / shooting: face the camera, strafe
	elif dir.length() > 0.1:
		_face(atan2(-dir.x, -dir.z), delta, 1.0)
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
	sync_t += delta
	if sync_t >= 1.0 / SYNC_HZ:
		sync_t = 0.0
		if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			net_state.rpc(global_position, model_yaw, h_speed, mv_flags, hook_point if hook_t > 0.0 else Vector3.ZERO, on_f, Time.get_ticks_msec() / 1000.0)


var floor_changes := 0

func hook_active_now() -> bool:
	return hook_t > 0.0

func _face(target: float, delta: float, k: float) -> void:
	var diff := angle_difference(model_yaw, target)
	var step := diff * (1.0 - exp(-TURN_RATE * k * delta))
	step = clampf(step, -MAX_TURN * delta, MAX_TURN * delta)
	model_yaw = wrapf(model_yaw + step, -PI, PI)

func _probe(from: Transform3D, motion: Vector3, res: PhysicsTestMotionResult3D = null) -> bool:
	var prm := PhysicsTestMotionParameters3D.new()
	prm.from = from
	prm.motion = motion
	prm.margin = safe_margin
	return PhysicsServer3D.body_test_motion(get_rid(), prm, res)

## Walk up curbs / steps: probe ahead, and if a low obstacle blocks us, hop onto the ledge (the model eases up via vis_off).
func _try_step_up(delta: float) -> void:
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var sp := hv.length()
	if sp < 0.5:
		return
	var look := hv / sp * maxf(sp * delta * 1.25, STEP_LOOK)
	var col := PhysicsTestMotionResult3D.new()
	if not _probe(global_transform, look, col):
		return
	if col.get_collision_normal(0).y > 0.7:
		return   # a walkable slope, the slide handles it
	var up := Vector3.UP * STEP_H
	if _probe(global_transform, up):
		return   # low ceiling
	var raised := global_transform.translated(up)
	if _probe(raised, look):
		return   # too tall
	# exact ledge height from a ray just past the contact point (a capsule probe would rest on the corner and over-lift)
	var dirn := look.normalized()
	var from := col.get_collision_point(0) + dirn * 0.04 + Vector3.UP * (STEP_H + 0.05)
	var rq := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (STEP_H + 0.2), collision_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(rq)
	if hit.is_empty() or hit.normal.y < cos(floor_max_angle):
		return
	var gain: float = hit.position.y - global_position.y
	if gain < 0.02 or gain > STEP_H + 0.01:
		return
	global_position.y += gain + 0.004
	vis_off = maxf(-0.45, vis_off - gain)
	step_ups += 1

var step_ups := 0

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
func net_state(pos: Vector3, yaw: float, spd: float, flags := 0, aux := Vector3.ZERO, grounded := true, stamp := 0.0) -> void:
	t_pos = pos
	t_yaw = yaw
	t_speed = spd
	t_flags = flags
	t_aux = aux
	t_grounded = grounded
	if stamp > 0.0:
		var smp := Time.get_ticks_msec() / 1000.0 - stamp
		if not _clock_init or smp < _clock_off:
			_clock_off = smp
		else:
			_clock_off = lerpf(_clock_off, smp, 0.002)
		_clock_init = true
		if not _snaps.is_empty():
			var last: Dictionary = _snaps.back()
			if stamp <= last.t:
				return
			if last.pos.distance_to(pos) > 6.0:
				_snaps.clear()   # teleport / respawn: never glide across the map
		_snaps.append({"t": stamp, "pos": pos, "yaw": yaw, "spd": spd, "flags": flags, "aux": aux, "g": grounded})
		if _snaps.size() > 16:
			_snaps.pop_front()

## Remote players: render INTERP_DELAY in the past and interpolate between the two snapshots around that time.
func _puppet_step(delta: float) -> void:
	if _snaps.size() < 2:
		position = position.lerp(t_pos, 1.0 - exp(-16.0 * delta))
		model_yaw = lerp_angle(model_yaw, t_yaw, 1.0 - exp(-16.0 * delta))
		h_speed = t_speed
		return
	var ts := Time.get_ticks_msec() / 1000.0 - _clock_off - INTERP_DELAY
	while _snaps.size() > 2 and _snaps[1].t <= ts:
		_snaps.pop_front()
	var a: Dictionary = _snaps[0]
	var b: Dictionary = _snaps[1]
	if ts >= b.t:
		var vel: Vector3 = (b.pos - a.pos) / maxf(b.t - a.t, 0.001)
		vel.y = 0.0
		position = b.pos + vel * minf(ts - b.t, 0.1)
		model_yaw = b.yaw
		h_speed = b.spd
		t_flags = b.flags; t_aux = b.aux; t_grounded = b.g
	else:
		var f := clampf((ts - a.t) / maxf(b.t - a.t, 0.001), 0.0, 1.0)
		position = a.pos.lerp(b.pos, f)
		model_yaw = lerp_angle(a.yaw, b.yaw, f)
		h_speed = lerpf(a.spd, b.spd, f)
		var s: Dictionary = b if f > 0.5 else a
		t_flags = s.flags; t_aux = s.aux; t_grounded = s.g

func eff_flags() -> int:
	return mv_flags if is_local else t_flags

func _animate() -> void:
	var dt := get_physics_process_delta_time()
	var shr := 0.5 if has_status("shrink") else 1.0
	cur_shrink = lerpf(cur_shrink, shr, 1.0 - exp(-10.0 * dt))
	_update_feel(dt)
	var pk := 1.0 if alive else clampf(dying / POP_TIME, 0.0, 1.0)
	pk = pk * pk * (3.0 - 2.0 * pk) if not alive else 1.0
	var show_body := alive or dying > 0.0
	if model:
		model.rotation.y = model_yaw + MODEL_YAW + tw_cur
		var neg_sc := scooter_model != null and ult_is(&"goddard_scooter")
		if jim_scooter:
			jim_scooter.visible = alive and ult_is(&"goddard_scooter")
			jim_scooter.rotation.y = model_yaw + MODEL_YAW - PI / 2.0   # scooter.glb length axis is Z, jimmybase faces X natively
			jim_scooter.scale = Vector3.ONE * base_scale * cur_shrink
		model.visible = show_body and not ult_is(&"rocket_ship") and not neg_sc
		if scooter_model:
			scooter_model.visible = alive and neg_sc
			scooter_model.rotation.y = model_yaw + MODEL_YAW
			scooter_model.scale = Vector3.ONE * base_scale * cur_shrink
			scooter_model.position.y = scooter_off * base_scale * cur_shrink
			if neg_sc and scooter_anim and scooter_anim.current_animation != "nummeyscooter":
				scooter_anim.play("nummeyscooter")
		model.scale = Vector3.ONE * base_scale * cur_shrink * pk
	if gear:
		gear.rotation.y = model_yaw
		gear.scale = Vector3.ONE * cur_shrink * pk
		gear.visible = show_body
	_update_fx()
	_update_gun()
	if label:
		label.visible = alive and not is_local
	if team == Config.TEAM_JIMMY and jim_scooter != null and ult_is(&"goddard_scooter") and anim and anim.has_animation("jimmyscooter"):
		_play("jimmyscooter" if h_speed > 0.4 else "jimmyscooterstop", 1.0)
	else:
		if not is_local:
			vy_est = lerpf(vy_est, (position.y - _last_y) / maxf(dt, 0.001), 0.3)
		_last_y = position.y
		var grounded: bool = _was_floor if is_local else t_grounded
		air_time = 0.0 if grounded else air_time + dt
		gait = _gait_for(h_speed, air_time > 0.08)
		match gait:
			&"idle":
				_play(anim_idle, 1.0)
			&"walk":
				_play(anim_walk, _gait_speed(anim_walk, 0.5, 2.0))
			&"run":
				_play(anim_run, _gait_speed(anim_run, 0.45, 2.4))
			&"air":
				var vy := velocity.y if is_local else vy_est
				var fl := eff_flags()
				if (fl & 7) != 0 and anim_fly != "" and anim.has_animation(anim_fly):
					_play(anim_fly, 1.0, 0.15)   # jetpack thrust / glide / bubble float
				elif vy > -9.0 and anim.has_animation(anim_jump):
					_play(anim_jump, 1.0, 0.1)    # the jump clip covers the whole short arc
				elif vy <= -9.0 and anim.has_animation(anim_fall):
					_play(anim_fall, 1.0, 0.15)   # long fall
				elif cur_anim == anim_run:
					anim.speed_scale = 0.0   # fallback: hold a run frame
				else:
					_play(anim_run, 0.0, 0.12)
					anim.seek(FootTable.AIR_T.get(anim_run, 0.2), false)
	if anim:
		var tgt: float = FootTable.lift(cur_anim)
		lift_cur = lerpf(lift_cur, tgt, 1.0 - exp(-14.0 * dt))
	vis_off *= exp(-14.0 * dt)
	if model:
		model.position.y = lift_cur * cur_shrink + vis_off + (1.0 - pk) * 0.7

## Playback speed of a walk / run clip: ground speed matched (planted foot does not slide); negative = backpedal; strafe leg turn is compensated.
func _gait_speed(clip: String, lo: float, hi: float) -> float:
	var sp := h_speed / maxf(FootTable.gs(clip), 0.1)
	if strafe_on:
		sp /= maxf(cos(_strafe_resid), 0.55)
	sp = clampf(sp, lo, hi)
	return -sp if strafe_rev else sp

var _strafe_resid := 0.0

## Strafe / backpedal: when the body faces the aim but the velocity points elsewhere, turn the legs towards the move direction
## (hip twist, torso counter-rotated by FeelMod) and play the clip backwards for backpedal. Also the flinch envelope.
func _update_feel(dt: float) -> void:
	if is_local:
		vel_h = Vector2(velocity.x, velocity.z)
	else:
		vel_h = vel_h.lerp(Vector2(position.x - _prev_pos.x, position.z - _prev_pos.z) / maxf(dt, 0.001), 0.35)
	_prev_pos = position
	var walking := (gait == &"walk" or gait == &"run") and alive and not ult_is(&"goddard_scooter") and not ult_is(&"rocket_ship")
	var spd := vel_h.length()
	var tw_tgt := 0.0
	_strafe_resid = 0.0
	if walking and spd > 0.6:
		var heading := atan2(-vel_h.x, -vel_h.y)
		var e_raw := absf(angle_difference(model_yaw, heading))
		if e_raw > (0.45 if strafe_on else 0.6):
			strafe_t += dt
		else:
			strafe_t = 0.0
		strafe_on = strafe_t > 0.18 or (strafe_on and e_raw > 0.45)
		if strafe_on:
			strafe_rev = e_raw > (PI * 0.5 - 0.2 if strafe_rev else PI * 0.5 + 0.2)
			var e_leg := angle_difference(model_yaw, heading + (PI if strafe_rev else 0.0))
			tw_tgt = clampf(e_leg, -TW_MAX, TW_MAX)
			_strafe_resid = e_leg - tw_cur
	else:
		strafe_on = false
		strafe_rev = false
		strafe_t = 0.0
	tw_cur = lerpf(tw_cur, tw_tgt, 1.0 - exp(-12.0 * dt))
	flinch_t = maxf(0.0, flinch_t - dt)
	if feel_mod:
		feel_mod.twist = tw_cur
		feel_mod.facing = model_yaw
		feel_mod.flinch = sin(PI * (1.0 - flinch_t / FLINCH_TIME)) if flinch_t > 0.0 else 0.0
		feel_mod.flinch_side = flinch_side
	dying = maxf(0.0, dying - dt)

## Upper-body flinch (no knockback); `from` = world position of the attacker (optional).
func flinch(from := Vector3.ZERO) -> void:
	flinch_t = FLINCH_TIME
	flinch_side = 0.0
	if from != Vector3.ZERO:
		var d := Vector3(from.x - global_position.x, 0.0, from.z - global_position.z).normalized()
		flinch_side = clampf(d.dot(Vector3(cos(model_yaw), 0.0, -sin(model_yaw))), -1.0, 1.0)

const FLASH_COL := {&"bubble_gun": Color(0.7, 0.95, 1.0), &"burp_gun": Color(0.9, 1.0, 0.3), &"water_gun": Color(0.4, 0.7, 1.0), &"mega_burp": Color(1.0, 0.7, 0.2), &"baseball": Color(1.0, 1.0, 1.0), &"rocket": Color(1.0, 0.5, 0.15)}
const FLASH_SIZE := {&"bubble_gun": 0.13, &"burp_gun": 0.2, &"water_gun": 0.08, &"mega_burp": 0.28, &"baseball": 0.14, &"rocket": 0.3}

## Short additive flash at the barrel tip (one pooled node, colour / size per weapon).
func muzzle_flash(wid: StringName) -> void:
	if flash == null:
		flash = Node3D.new()
		flash.top_level = true
		flash.visible = false
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color.WHITE
		m.no_depth_test = true
		for sc in [Vector3(1, 1, 1), Vector3(0.45, 0.45, 2.6)]:
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0; sm.radial_segments = 8; sm.rings = 4
			mi.mesh = sm
			mi.material_override = m
			mi.scale = sc
			flash.add_child(mi)
		add_child(flash)
	var c: Color = FLASH_COL.get(wid, Color(1, 1, 0.8))
	((flash.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, 0.9)
	flash.set_meta("size", FLASH_SIZE.get(wid, 0.15))
	flash_t = flash_peak

func _update_flash(dt: float) -> void:
	if flash == null:
		return
	flash_t = maxf(0.0, flash_t - dt)
	flash.visible = flash_t > 0.0 and alive and palm != null and fx_gun != null and fx_gun.visible
	if flash.visible:
		var aim := fx_gun.global_transform.basis.orthonormalized()
		var k := flash_t / flash_peak
		var sz: float = flash.get_meta("size") * (0.6 + 0.8 * (1.0 - k) if k > 0.5 else k * 2.0 + 0.2)
		flash.global_transform = Transform3D(aim.scaled(Vector3.ONE * sz), palm.global_position + (-aim.z) * 0.55 * cur_shrink)

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
		var on := (fl & 1) != 0 and alive
		fx_jet.visible = on
		var dtj := get_physics_process_delta_time()
		jet_k = move_toward(jet_k, 1.0 if on else 0.0, dtj * 7.0)   # expand on ignition, shrink on cut-off (jetpack.glb has no expand/shrink clips)
		if on:
			var t := Time.get_ticks_msec() / 1000.0
			var i := 0
			for n in fx_jet.get_children():
				var fk := 1.0 + 0.22 * sin(t * 47.0 + i * 2.1) + 0.12 * sin(t * 83.0 + i)
				var ov := 1.0 + 0.25 * (1.0 - jet_k)
				(n as Node3D).scale = Vector3(fk * 0.9, fk * 0.9, fk * 1.15) * jet_k * ov
				i += 1
	if fx_shield:
		fx_shield.visible = alive and (has_status("shield") or (fl & 4) != 0)
		var m := fx_shield as MeshInstance3D
		if m and m.material_override:
			(m.material_override as StandardMaterial3D).albedo_color = Color(0.4, 1.0, 0.6, 0.28) if (fl & 4) != 0 and not has_status("shield") else Color(0.3, 0.7, 1.0, 0.3)
	var riding := ult_is(&"goddard_scooter")
	for ba in boot_ba:
		ba.visible = not riding
	if fx_sprint:
		fx_sprint.visible = alive and (fl & 16) != 0 and h_speed > 2.0 and not riding
		if fx_sprint.visible:
			var ts := Time.get_ticks_msec() / 1000.0
			for j in fx_sprint.get_child_count():
				var sn := fx_sprint.get_child(j) as Node3D
				sn.position.z = 0.9 + fposmod(ts * 5.0 + j * 0.31, 1.2)
	if fx_ship:
		fx_ship.visible = alive and (ult_is(&"rocket_ship") or (ult_is(&"goddard_scooter") and ((team == Config.TEAM_JIMMY and jim_scooter == null) or (team == Config.TEAM_NEGATRON and scooter_model == null))))
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
	if alive and model != null and is_inside_tree():
		dying = POP_TIME
		var tc: Color = Config.TEAM_COLORS[team]
		Fx.burst(get_parent(), global_position + Vector3(0, 0.9, 0), [tc, Color.WHITE, Color(1, 0.85, 0.2), Color(1, 0.4, 0.7)], 28, 4.5, 0.07, 0.9, 6.0)
	alive = false
	collision_layer = 0
	status.clear()
	hook_t = 0.0
	if not is_local:
		t_speed = 0.0

func set_alive_at(t: Transform3D) -> void:
	alive = true
	dying = 0.0
	flinch_t = 0.0
	hp = max_hp
	status.clear()
	hook_t = 0.0
	gadget_cd = 0.0
	fuel = movement.f("fuel", 100.0)
	collision_layer = 2
	if is_local:
		global_position = t.origin
		velocity = Vector3.ZERO
		vis_off = 0.0
		cam_ready = false
		cam_yaw = t.basis.get_euler().y
		model_yaw = cam_yaw
	else:
		global_position = t.origin
		t_pos = t.origin
		_snaps.clear()

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
	if jp_attach:
		jp_attach.queue_free(); jp_attach = null
	for ba in boot_ba:
		ba.queue_free()
	boot_ba.clear()
	if fx_hook:
		fx_hook.queue_free(); fx_hook = null
	if fx_rope:
		fx_rope.queue_free(); fx_rope = null
	gear = Node3D.new()
	add_child(gear)
	fx_jet = null; fx_shield = null; fx_ship = null; fx_drone = null; fx_boots = null; fx_sprint = null
	# held weapon: procedural model (WeaponModel), posed at the right palm and aimed every frame by _update_gun()
	if fx_gun:
		fx_gun.queue_free()
	if gun_ba:
		gun_ba.queue_free(); gun_ba = null
	fx_gun = WeaponModel.build(weapon.id)
	fx_gun.top_level = true
	add_child(fx_gun)
	_attach_palm()
	match movement.id:
		&"jetpack":
			_build_jetpack()
		&"goof_boots":
			_build_boots()
		&"none":
			_build_plating()
		&"sprint":
			fx_sprint = Node3D.new()
			for i in 6:
				var st := Fx.box(Vector3(0.035, 0.035, 1.5), Color(1, 1, 1, 0.8))
				st.position = Vector3(-0.55 + 0.22 * i, 0.3 + 0.3 * (i % 4), 0.9)
				fx_sprint.add_child(st)
			fx_sprint.visible = false
			gear.add_child(fx_sprint)
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
		Fx.translucent(bub, 0.3)
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
	fx_ship.position.y = 0.6 if ultimate.id == &"rocket_ship" else 0.0
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
		fx_ship.add_child(Fx.box(Vector3(0.4, 0.2, 1.0), Color(0.45, 0.55, 0.25)))   # fallback when scooter.glb is missing
	fx_ship.visible = false
	gear.add_child(fx_ship)
	fx_drone = WeaponModel.drone()
	fx_drone.visible = false
	gear.add_child(fx_drone)

## Backpack (jetpack.glb, Granny model in raw units) bolted to the spine bone; flames at its two nozzles while thrusting.
## Heavy Plating: chest plate + shoulder pads on the gear node (rotates with the body; torso height ~0.85 m).
func _build_plating() -> void:
	var holder := Node3D.new()
	holder.position = Vector3(0, 0.5, -0.02)
	gear.add_child(holder)
	var steel := Color(0.55, 0.58, 0.66)
	WeaponModel.block(holder, Vector3(0, 0, -0.1), Vector3(0.28, 0.24, 0.06), steel, 0.7)
	WeaponModel.block(holder, Vector3(0, 0, -0.135), Vector3(0.18, 0.14, 0.02), Color(0.85, 0.7, 0.2), 0.6)
	WeaponModel.block(holder, Vector3(0, 0.02, 0.13), Vector3(0.28, 0.24, 0.05), steel, 0.7)
	for sx in [-1.0, 1.0]:
		WeaponModel.ball(holder, Vector3(0.18 * sx, 0.13, 0.0), 0.06, steel, 0.7)

func _build_boots() -> void:
	var sk: Skeleton3D = null
	if model:
		var l := model.find_children("*", "Skeleton3D", true, false)
		if l.size() > 0:
			sk = l[0] as Skeleton3D
	fx_boots = Node3D.new()   # bookkeeping node (visibility is applied to the attachments)
	gear.add_child(fx_boots)
	if sk == null:
		return
	for side in ["L", "R"]:
		var bn := "Bip01 %s Foot" % side
		if sk.find_bone(bn) < 0:
			continue
		var ba := BoneAttachment3D.new()
		ba.bone_name = bn
		sk.add_child(ba)
		boot_ba.append(ba)
		var h := Node3D.new()
		# foot bone: +X down the shin, -Z toward the toe; boot glb: +Y up, +Z forward
		h.transform = Transform3D(Basis(Vector3(0, -1, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1)), BOOT_OFF)
		var b := Fx.model("ase/n2/goofbootfly.glb")
		if b:
			Fx.fit(b, BOOT_SIZE)
			h.add_child(b)
		else:
			h.add_child(Fx.box(Vector3(10, 12, 24), Color(0.9, 0.8, 0.2)))
		ba.add_child(h)

func _build_jetpack() -> void:
	var sk: Skeleton3D = null
	if model:
		var l := model.find_children("*", "Skeleton3D", true, false)
		if l.size() > 0:
			sk = l[0] as Skeleton3D
	var jp := Assets.try_scene("jetpack.glb") as Node3D
	if sk == null or sk.find_bone("Bip01 Spine") < 0 or jp == null:
		# art missing: old floating box fallback
		var holder := Node3D.new()
		holder.position = Vector3(0, 0.95, 0.28)
		holder.add_child(Fx.box(Vector3(0.3, 0.5, 0.2), Color(0.6, 0.6, 0.65)))
		gear.add_child(holder)
		fx_jet = Node3D.new()
		fx_jet.position = Vector3(0, 0.55, 0.28)
		fx_jet.add_child(Fx.sphere(0.12, Color(1.0, 0.6, 0.1, 0.9)))
		fx_jet.visible = false
		gear.add_child(fx_jet)
		return
	jp_attach = BoneAttachment3D.new()
	jp_attach.bone_name = "Bip01 Spine"
	sk.add_child(jp_attach)
	var holder2 := Node3D.new()
	holder2.transform = Balance.JETPACK_XF
	holder2.add_child(jp)
	jp_attach.add_child(holder2)
	jp_attach.set_meta("jp", true)
	# flames: bottom corners of the pack (raw units, in the holder's frame)
	fx_jet = Node3D.new()
	var bb := Fx.aabb_of(jp)
	for sy in [0.2, 0.8]:
		var nozzle := Node3D.new()
		nozzle.position = Vector3(bb.position.x, bb.position.y + bb.size.y * sy, bb.position.z + bb.size.z * 0.5)   # exhaust end = jp -x
		var fl := Fx.model("ase/n1/fire.glb")
		if fl:
			Fx.fit(fl, 1.0 / maxf(base_scale, 0.0001))
			fl.rotation.y = PI / 2.0   # point the flame along the pack's -x (down)
			nozzle.add_child(fl)
		else:
			nozzle.add_child(Fx.sphere(0.1 / maxf(base_scale, 0.0001), Color(1.0, 0.6, 0.1, 0.9)))
		fx_jet.add_child(nozzle)
	fx_jet.visible = false
	holder2.add_child(fx_jet)

## Palm marker (centre of the right hand mesh, bone-local raw units measured with tools/handprobe.gd) on the right-hand bone.
func _attach_palm() -> void:
	var sk: Skeleton3D = null
	if model:
		var l := model.find_children("*", "Skeleton3D", true, false)
		if l.size() > 0:
			sk = l[0] as Skeleton3D
	if sk == null or sk.find_bone("Bip01 R Hand") < 0:
		return
	gun_ba = BoneAttachment3D.new()
	gun_ba.bone_name = "Bip01 R Hand"
	sk.add_child(gun_ba)
	palm = Node3D.new()
	palm.position = PALM_NEG if team == Config.TEAM_NEGATRON else PALM_JIM
	gun_ba.add_child(palm)

## Keeps the held weapon in the palm with its barrel along the aim (body yaw, plus camera pitch for the local player).
func _update_gun() -> void:
	_update_flash(get_physics_process_delta_time())
	if fx_gun == null:
		return
	var show := alive and model != null and model.visible and palm != null
	fx_gun.visible = show
	if not show:
		return
	var pitch := 0.0
	if is_local and cam_pivot:
		pitch = cam_pitch * (1.0 if shoot_pose > 0.0 else 0.4)
	var b := Basis.from_euler(Vector3(pitch, model_yaw, 0.0)).scaled(Vector3.ONE * cur_shrink)
	fx_gun.global_transform = Transform3D(b, palm.global_position)
