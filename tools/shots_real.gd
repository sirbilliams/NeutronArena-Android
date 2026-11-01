extends Node
## Real-input repro of "Jimmy runs face-first": real match (no test_mode), joins Jimmy, holds left stick UP through
## Input.parse_input_event, screenshots from the player's own camera and prints move dir vs face dir.
## tools/vrun.sh res://tools/shots_real.tscn
var out := "/home/bill/Projects/arena-assets/shots/real"
var world: World

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])

func _stick(y: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0; e.axis = JOY_AXIS_LEFT_Y; e.axis_value = y
	Input.parse_input_event(e)

func _report(me: Player, tag: String) -> void:
	var head := me.model.global_transform.basis * Vector3(1, 0, 0)   # glb native forward (+X) in world
	var sk := AnimFix._find_skeleton(me.model)
	var face := Vector3.ZERO
	if sk:
		var l := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Bip01 L Thigh")).origin
		var r := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Bip01 R Thigh")).origin
		face = (l - r).cross(Vector3.UP); face.y = 0; face = face.normalized()
	var v := Vector3(me.velocity.x, 0, me.velocity.z)
	var camf := -me.cam.global_transform.basis.z; camf.y = 0
	print("%s model_yaw=%.2f cam_yaw=%.2f heading=%.2f tw=%.2f shoot_pose=%.2f strafe=%s rev=%s" % [tag, me.model_yaw, me.cam_yaw, atan2(-v.x, -v.z), me.tw_cur, me.shoot_pose, me.strafe_on, me.strafe_rev])
	print("%s clip=%s vel=%s camfwd=%s modelX=%s thighface=%s  face·vel=%.2f" % [tag, me.anim.current_animation, v.normalized().snapped(Vector3.ONE*0.01), camf.normalized().snapped(Vector3.ONE*0.01), head.snapped(Vector3.ONE*0.01), face.snapped(Vector3.ONE*0.01), face.dot(v.normalized())])

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	Config.test_mode = false
	Config.bots_enabled = false
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(24778, 10)
	multiplayer.multiplayer_peer = peer
	world = World.new(); add_child(world)
	world.build()
	world.start_server()
	for i in 120:
		await get_tree().physics_frame
	var team := Config.TEAM_JIMMY
	for a in OS.get_cmdline_user_args():
		if a == "--negatron": team = Config.TEAM_NEGATRON; out += "_neg"
	DirAccess.make_dir_recursive_absolute(out)
	world.request_team(team)
	for i in 120:
		await get_tree().physics_frame
	var me: Player = world.players.get(1)
	if me == null:
		print("no player"); get_tree().quit(); return
	_report(me, "idle   ")
	await _shot("0_idle")
	_stick(-1.0)
	for i in 90:
		await get_tree().physics_frame
	_report(me, "stickUP")
	await _shot("1_stick_up")
	_stick(0.0)
	for i in 30:
		await get_tree().physics_frame
	var k := InputEventKey.new(); k.keycode = KEY_W; k.physical_keycode = KEY_W; k.pressed = true
	Input.parse_input_event(k)
	for i in 90:
		await get_tree().physics_frame
	_report(me, "key W  ")
	await _shot("2_key_w")
	get_tree().quit()
