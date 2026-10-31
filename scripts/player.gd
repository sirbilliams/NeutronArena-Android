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
	if is_local:
		_build_camera()

func _build_model() -> void:
	var rel := "jimmy.glb" if team == Config.TEAM_JIMMY else "nummey_villain.glb"
	model = Assets.load_scene(rel) as Node3D
	if model == null:
		model = MeshInstance3D.new()
		(model as MeshInstance3D).mesh = CapsuleMesh.new()
	var s := Config.WORLD_SCALE
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
	shoot_pose = maxf(0.0, shoot_pose - delta)
	if is_local:
		_local_step(delta)
	else:
		position = position.lerp(t_pos, 1.0 - exp(-16.0 * delta))
		model_yaw = lerp_angle(model_yaw, t_yaw, 1.0 - exp(-16.0 * delta))
		h_speed = t_speed
	_animate()

func _local_step(delta: float) -> void:
	var dead_or_over: bool = (not alive) or world.match_over
	var mv := Vector2.ZERO
	var firing := false
	if Config.test_mode:
		mv = test_move
	elif not dead_or_over:
		mv = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		firing = Input.is_action_pressed("fire")
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		cam_yaw -= look.x * STICK_SENS * delta
		cam_pitch = clampf(cam_pitch - look.y * STICK_SENS * delta, -1.3, 1.0)
	if not alive:
		mv = Vector2.ZERO
	var dir := Basis(Vector3.UP, cam_yaw) * Vector3(mv.x, 0, mv.y)
	if is_on_floor():
		velocity.x = dir.x * RUN_SPEED
		velocity.z = dir.z * RUN_SPEED
		if alive and not Config.test_mode and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_SPEED
	else:
		velocity.x = move_toward(velocity.x, dir.x * RUN_SPEED, 20.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * RUN_SPEED, 20.0 * delta)
	velocity.y -= GRAVITY * delta
	move_and_slide()
	h_speed = Vector2(velocity.x, velocity.z).length()
	if global_position.y < -40.0:  # fell out of the world
		var sp: Transform3D = world.level.spawn_point(team, 0)
		global_position = sp.origin
		velocity = Vector3.ZERO
	if dir.length() > 0.1:
		var target := atan2(-dir.x, -dir.z)
		model_yaw = lerp_angle(model_yaw, target, 1.0 - exp(-14.0 * delta))
	if shoot_pose > 0.0:
		model_yaw = lerp_angle(model_yaw, cam_yaw, 1.0 - exp(-20.0 * delta))
	if firing and alive and fire_cd <= 0.0:
		fire(aim_direction_from_camera())
	_update_cam()
	sync_t += delta
	if sync_t >= 1.0 / SYNC_HZ:
		sync_t = 0.0
		net_state.rpc(global_position, model_yaw, h_speed)

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
func fire(dir: Vector3) -> void:
	if fire_cd > 0.0:
		return
	fire_cd = weapon.fire_interval
	shoot_pose = 0.4
	world.request_fire_local(muzzle() + dir.normalized() * 0.5, dir)

@rpc("authority", "unreliable_ordered")
func net_state(pos: Vector3, yaw: float, spd: float) -> void:
	t_pos = pos
	t_yaw = yaw
	t_speed = spd

func _animate() -> void:
	if model:
		model.rotation.y = model_yaw + MODEL_YAW
		model.visible = alive
	if label:
		label.visible = alive and not is_local
	if h_speed > 0.4:
		_play(anim_run, clampf(h_speed / RUN_SPEED, 0.6, 1.4))
	else:
		_play(anim_idle, 1.0)

func set_dead() -> void:
	alive = false
	collision_layer = 0
	if not is_local:
		t_speed = 0.0

func set_alive_at(t: Transform3D) -> void:
	alive = true
	hp = Config.MAX_HP
	collision_layer = 2
	if is_local:
		global_position = t.origin
		velocity = Vector3.ZERO
		cam_yaw = t.basis.get_euler().y
		model_yaw = cam_yaw
	else:
		global_position = t.origin
		t_pos = t.origin
