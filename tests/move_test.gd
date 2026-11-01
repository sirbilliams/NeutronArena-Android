extends Node3D
## Headless movement test on a synthetic course (+ real Carl curb if the art is present).
## godot --headless --path . res://tests/move_test.tscn      (see tests/run_move_test.sh)
class StubWorld extends Node:
	var match_over := false
	func local_team() -> int:
		return 0

var fails := 0
var player: Player
var parts := {}
var floor_y_at := 0.0

func check(c: bool, m: String) -> void:
	print("  [", "ok" if c else "FAIL", "] ", m)
	if not c:
		fails += 1

func box(pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new(); sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos
	sb.rotation = rot
	course.add_child(sb)

var course: Node3D

func build_course() -> void:
	course = Node3D.new()
	add_child(course)
	box(Vector3(50, -1, 40), Vector3(200, 2, 200))                       # floor, top y=0
	box(Vector3(12.5, 0.1, 0), Vector3(5, 0.2, 40))                      # 0.20 m curb, x 10..15
	box(Vector3(22.5, 0.17, 0), Vector3(5, 0.34, 40))                    # 0.34 m step, x 20..25
	box(Vector3(31, 0.4, 0), Vector3(2, 0.8, 40))                        # 0.8 m wall, x 30..32
	var a := deg_to_rad(20.0)                                            # lane B (z=40): 20 degree ramp from x=10
	var n := Vector3(-sin(a), cos(a), 0)
	box(Vector3(10, 0, 40) + Vector3(cos(a), sin(a), 0) * 10.0 - n * 1.0, Vector3(20, 2, 20), Vector3(0, 0, a))
	box(Vector3(10, 0.5, 80), Vector3(20, 1.0, 20))                      # lane C (z=80): 1 m ledge, edge at x=20

func spawn(team: int, pos: Vector3) -> void:
	if player:
		player.queue_free()
		await get_tree().physics_frame
	player = Player.new()
	player.peer_id = 1
	player.team = team
	player.world = StubWorld.new()
	player.position = pos
	add_child(player)
	player.test_move = Vector2.ZERO
	await ticks(1.0)   # settle
	await get_tree().process_frame

func ticks(seconds: float) -> void:
	for i in int(round(seconds * Engine.physics_ticks_per_second)):
		await get_tree().physics_frame

func hspeed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()

func floor_below() -> float:
	var q := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 1.0, 0), player.global_position + Vector3(0, -3.0, 0), 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r.position.y if r else -99.0

## lowest skinned vertex of the current pose in world space minus the floor under the player (m)
func foot_gap(rel: String) -> float:
	var sk: Skeleton3D = player.model.find_children("*", "Skeleton3D", true, false)[0]
	if not parts.has(rel):
		parts[rel] = FootSkin.load_parts(rel, player.model)
	var low := FootSkin.lowest(sk, parts[rel])
	var xf := sk.global_transform
	var wy := xf.origin.y + low * xf.basis.get_scale().y
	return wy - floor_below()

func sample_gap(rel: String, label: String, n: int, every: int) -> Dictionary:
	var lo := 1e9; var hi := -1e9; var sum := 0.0
	for i in n:
		await ticks(every / float(Engine.physics_ticks_per_second))
		var g := foot_gap(rel)
		lo = minf(lo, g); hi = maxf(hi, g); sum += g
	print("    gap %-22s min %+.1f cm  mean %+.1f cm  max %+.1f cm  (anim %s, gait %s)" % [label, lo * 100, sum / n * 100, hi * 100, player.cur_anim, player.gait])
	return {"min": lo, "mean": sum / n, "max": hi}

func run_character(team: int, rel: String, name: String) -> void:
	print("== ", name, " grounding @", Engine.physics_ticks_per_second, " Hz")
	await spawn(team, Vector3(-3, 0.3, 120))
	var g := await sample_gap(rel, "idle", 4, 7)
	check(absf(g.min) < 0.02 and absf(g.max) < 0.02, "%s idle foot gap %.1f cm" % [name, g.mean * 100])
	player.test_move = Vector2(0.3, 0)
	await ticks(0.6)
	g = await sample_gap(rel, "walk (stick 0.3)", 8, 5)
	check(player.gait == &"walk", "%s gait walk at %.2f m/s" % [name, hspeed()])
	check(g.min > -0.02 and g.min < 0.02, "%s walk foot contact gap %.1f cm" % [name, g.min * 100])
	player.test_move = Vector2(1, 0)
	await ticks(0.8)
	g = await sample_gap(rel, "run", 10, 4)
	check(player.gait == &"run", "%s gait run at %.2f m/s" % [name, hspeed()])
	check(g.min > -0.02 and g.min < 0.02, "%s run foot contact gap %.1f cm" % [name, g.min * 100])
	check(absf(hspeed() - 6.0) < 0.15, "%s run speed %.2f m/s" % [name, hspeed()])
	# jump + land
	player.test_move = Vector2.ZERO
	await ticks(0.6)
	player.test_jump = true; player.test_jump_held = true
	await ticks(0.2)
	check(player.gait == &"air" or not player.is_on_floor(), "%s airborne after jump (gait %s)" % [name, player.gait])
	player.test_jump_held = false
	await ticks(1.2)
	g = await sample_gap(rel, "after landing", 3, 6)
	check(player.is_on_floor() and absf(g.mean) < 0.02, "%s landed, foot gap %.1f cm" % [name, g.mean * 100])

func run_flat(label: String) -> void:
	print("== flat walk ", label)
	await spawn(Config.TEAM_JIMMY, Vector3(-4, 0.3, 0))
	player.test_move = Vector2(1, 0)
	await ticks(0.5)
	var c0 := player.floor_changes
	var n := 0; var sum := 0.0; var sq := 0.0
	for i in int(2.0 * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		var s := hspeed(); n += 1; sum += s; sq += s * s
		if player.global_position.x > 9.0: break
	var mean := sum / n
	check(player.floor_changes - c0 == 0, "no is_on_floor flicker over %d flat frames (%d changes)" % [n, player.floor_changes - c0])
	check(absf(mean - 6.0) < 0.1 and sqrt(maxf(sq / n - mean * mean, 0.0)) < 0.1, "velocity steady %.2f +/- %.3f m/s" % [mean, sqrt(maxf(sq / n - mean * mean, 0.0))])
	player.test_move = Vector2.ZERO
	await ticks(0.4)
	var p := player.global_position
	await ticks(1.0)
	check(hspeed() < 0.01 and player.global_position.distance_to(p) < 0.005, "no sliding when idle (drift %.1f mm)" % (player.global_position.distance_to(p) * 1000))

func run_curb(label: String) -> void:
	print("== curb / step ", label)
	Engine.time_scale = 1.0
	await spawn(Config.TEAM_JIMMY, Vector3(5, 0.3, 0))
	player.test_move = Vector2(1, 0)
	var su0 := player.step_ups
	var minv := 99.0; var maxy := 0.0; var c0 := player.floor_changes
	var ys := []
	for i in int(2.0 * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		var x := player.global_position.x
		if x > 9.0 and x < 14.0:
			minv = minf(minv, hspeed())
		if x > 10.0 and x < 15.0:
			maxy = maxf(maxy, player.global_position.y)
			ys.append(player.global_position.y)
		if x > 16.0: break
	check(player.step_ups - su0 >= 1, "0.20 m curb: step-up succeeded (%d)" % (player.step_ups - su0))
	check(maxy > 0.19 and maxy < 0.23, "curb top reached with no overshoot / bounce (max y %.3f)" % maxy)
	check(minv > 5.0, "no stick at the curb: min speed %.2f m/s" % minv)
	# after the 0.2 drop at x=15 the model must hop down smoothly via floor snap and still be grounded
	await ticks(0.5)
	check(player.is_on_floor(), "grounded after stepping off the curb")
	var gv := player.vis_off
	# 0.34 m step at x=20
	var su1 := player.step_ups
	player.global_position = Vector3(18.0, 0.05, 0.0)
	await ticks(1.0)
	check(player.global_position.x > 22.0 and player.step_ups > su1, "0.34 m step climbed (x %.1f, y %.3f)" % [player.global_position.x, player.global_position.y])
	# wall 0.8 m blocks
	player.global_position = Vector3(27.0, 0.05, 0.0)
	await ticks(1.2)
	check(player.global_position.x < 29.8 and player.global_position.y < 0.5, "0.8 m wall blocks (x %.2f y %.2f)" % [player.global_position.x, player.global_position.y])
	check(hspeed() < 0.5, "pressing into the wall does not jitter (speed %.2f)" % hspeed())

func run_slope(label: String) -> void:
	print("== 20 degree slope ", label)
	Engine.time_scale = 1.0
	await spawn(Config.TEAM_JIMMY, Vector3(8, 0.3, 40))
	player.test_move = Vector2(1, 0)
	await ticks(0.6)
	var c0 := player.floor_changes
	var sp := 0.0; var n := 0
	for i in int(1.2 * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		sp += hspeed(); n += 1
	var expect_h := 6.0 * cos(deg_to_rad(20.0))
	check(player.floor_changes - c0 == 0, "no floor flicker climbing the slope (%d)" % (player.floor_changes - c0))
	check(absf(sp / n - 6.0) < 0.6 or absf(sp / n - expect_h) < 0.6, "constant speed on the slope: |v| %.2f m/s" % (sp / n))
	player.test_move = Vector2.ZERO
	await ticks(0.6)
	var p := player.global_position
	await ticks(1.0)
	check(player.global_position.distance_to(p) < 0.005 and player.is_on_floor(), "stands still on the slope (drift %.1f mm)" % (player.global_position.distance_to(p) * 1000))
	# run down
	player.cam_yaw = 0.0
	player.test_move = Vector2(-1, 0)
	await ticks(0.5)
	c0 = player.floor_changes
	await ticks(0.8)
	check(player.floor_changes - c0 == 0 and player.is_on_floor(), "stays glued going down the slope (%d floor changes)" % (player.floor_changes - c0))

func run_jump(label: String) -> void:
	print("== jump: coyote / buffer / height ", label)
	Engine.time_scale = 1.0   # physics_frame fires once per rendered frame: 1x keeps one tick per await
	await spawn(Config.TEAM_JIMMY, Vector3(0, 0.3, 0))
	var y0 := player.global_position.y
	player.test_jump = true; player.test_jump_held = true
	var top := 0.0
	for i in int(1.5 * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		top = maxf(top, player.global_position.y - y0)
		if i > 3: player.test_jump_held = true
	var expect_h := 6.5 * 6.5 / (2.0 * 20.0)
	check(absf(top - expect_h) < 0.12, "jump apex %.2f m (expect %.2f, identical physics at any tick rate)" % [top, expect_h])
	# coyote: run off the 1 m ledge at x=20 (z=80), press jump shortly after leaving
	for delay in [0.06, 0.3]:
		await spawn(Config.TEAM_JIMMY, Vector3(17, 1.05, 80))
		player.test_move = Vector2(1, 0)
		var left := false
		var t := 0
		var jumped := false
		for i in int(2.0 * Engine.physics_ticks_per_second):
			await get_tree().physics_frame
			if not left and not player.is_on_floor():
				left = true; t = 0
			if left:
				t += 1
				if not jumped and t / float(Engine.physics_ticks_per_second) >= delay:
					player.test_jump = true; player.test_jump_held = true
					jumped = true
					await get_tree().physics_frame
					break
		var rose: bool = player.velocity.y > 3.0
		if delay < 0.12:
			check(rose, "coyote: jump %.2f s after leaving the ledge works (vy %.1f)" % [delay, player.velocity.y])
		else:
			check(not rose, "no air jump %.2f s after leaving the ledge (vy %.1f)" % [delay, player.velocity.y])
	# buffer: press jump 0.08 s before landing
	await spawn(Config.TEAM_JIMMY, Vector3(0, 0.3, 0))
	player.test_jump = true; player.test_jump_held = true
	var pressed := false
	var up_after := false
	var landed_tick := -1
	for i in int(3.0 * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		var fy := player.global_position.y
		if not pressed and player.velocity.y < 0.0 and fy / maxf(-player.velocity.y, 0.1) <= 0.08:
			player.test_jump = true
			pressed = true
		if pressed and player.is_on_floor() and landed_tick < 0:
			landed_tick = i
		if landed_tick >= 0 and i <= landed_tick + 8 and player.velocity.y > 3.0:
			up_after = true
	check(pressed and up_after, "jump buffer: early press fires on landing")
	Engine.time_scale = 3.0

func run_remote() -> void:
	print("== remote interpolation (jittered 20 Hz snapshots, 6 m/s)")
	await spawn(Config.TEAM_NEGATRON, Vector3(0, 0.3, 120))
	var rp := Player.new()
	rp.peer_id = 2
	rp.team = Config.TEAM_NEGATRON
	rp.world = StubWorld.new()
	rp.position = Vector3(0, 0, 140)
	add_child(rp)
	await get_tree().physics_frame
	var t0 := Time.get_ticks_msec() / 1000.0
	var maxstep := 0.0
	var prev := rp.position
	var next_send := 0.0
	var err_max := 0.0
	var steps := []
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var pending := []   # [arrival, stamp]
	var sent_i := 0
	while true:
		await get_tree().physics_frame
		var now := Time.get_ticks_msec() / 1000.0 - t0
		if now > 3.0: break
		while next_send <= now:
			pending.append([next_send + rng.randf() * 0.03, next_send])   # up to 30 ms network jitter
			next_send += 0.05
		var keep := []
		for pk in pending:
			if pk[0] <= now:
				var st: float = pk[1]
				rp.net_state(Vector3(st * 6.0, 0, 140), 0.0, 6.0, 0, Vector3.ZERO, true, t0 + st)
			else:
				keep.append(pk)
		pending = keep
		if now > 1.0:
			var d := rp.position.x - prev.x
			steps.append(d)
			err_max = maxf(err_max, absf(rp.position.x - (now - Player.INTERP_DELAY) * 6.0))
		prev = rp.position
	var mean := 0.0
	for d in steps: mean += d
	mean /= steps.size()
	var var_ := 0.0
	for d in steps: var_ += (d - mean) * (d - mean)
	var sd := sqrt(var_ / steps.size())
	# per-tick step relative to the mean step
	check(sd < mean * 0.25, "smooth: per-tick step %.3f m +/- %.3f" % [mean, sd])
	check(err_max < 0.5, "tracks the sender ~%d ms behind (max error %.2f m)" % [int(Player.INTERP_DELAY * 1000), err_max])
	check(rp.gait == &"run", "remote animates as run (gait %s)" % rp.gait)
	rp.queue_free()

func run_real_curb() -> void:
	print("== real Carl city curb")
	if not Config.assets_ok():
		print("  (art missing, skipped)")
		return
	course.queue_free()
	await get_tree().physics_frame
	var lv := ArenaLevel.new()
	add_child(lv)
	if not lv.load_level():
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	# curb at x=27.83 m on the z=-12.54 street line (found by tools/curbscan.gd): sidewalk 0.198 m below the road
	var z := -12.54
	player = null
	await spawn(Config.TEAM_JIMMY, Vector3(24.5, 0.0, z))
	player.test_move = Vector2(1, 0)
	var su0 := player.step_ups
	var floor_now := floor_below()
	var maxdy := 0.0
	var py := player.global_position.y
	var minv := 99.0
	for i in int(1.5 * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		if i % 6 == 0: print("    dbg3 i %d x %.2f y %.3f vx %.2f floor %s" % [i, player.global_position.x, player.global_position.y, player.velocity.x, player.is_on_floor()])
		var dy := player.global_position.y - py
		py = player.global_position.y
		maxdy = maxf(maxdy, absf(dy))
		if player.global_position.x > 25.5: minv = minf(minv, hspeed())
		if player.global_position.x > 32.0: break
	print("    start floor y %.3f, end y %.3f, x %.2f, step_ups %d, min speed past x=25.5: %.2f" % [floor_now, player.global_position.y, player.global_position.x, player.step_ups - su0, minv])
	check(player.global_position.x > 30.0 and player.step_ups - su0 >= 1, "crossed the real curb (x %.2f)" % player.global_position.x)
	check(minv > 4.5, "no stick on the real curb (min speed %.2f)" % minv)
	lv.queue_free()

## --cal: print the foot-lift table measured on the real Player model (paste into scripts/foot_table.gd)
func calibrate() -> void:
	for cfg in [[Config.TEAM_JIMMY, "jimmy.glb", ["jimmyidle", "jimmywalk", "jimmyfullrun", "jimmyscooter", "jimmyscooterstop", "jimmyjump", "jimmyfall", "jimmyfly"]], [Config.TEAM_NEGATRON, "nummey_villain.glb", ["nummeystop", "nummeywalk", "nummeyrun", "nummeyfly", "numflyair"]]]:
		await spawn(cfg[0], Vector3(-3, 0.3, 120))
		player.set_physics_process(false)
		var sk: Skeleton3D = player.model.find_children("*", "Skeleton3D", true, false)[0]
		var pts := FootSkin.load_parts(cfg[1], player.model)
		player.model.position.y = 0.0
		for c in cfg[2]:
			var a := player.anim.get_animation(c)
			player.anim.play(c, 0.0)
			player.anim.advance(a.length * 0.37)
			var ys := []
			for i in 40:
				player.anim.advance(a.length / 41.0)
				var xf := sk.global_transform
				ys.append(xf.origin.y + FootSkin.lowest(sk, pts) * xf.basis.get_scale().y - player.global_position.y)
			var raw := ys.duplicate()
			ys.sort()
			if "--series" in OS.get_cmdline_user_args():
				print("SERIES ", c, " ", raw.map(func(v): return snappedf(-v, 0.001)))
			print("CAL %s lift=%.4f (min %.4f median %.4f)" % [c, -ys[3], -ys[0], -ys[20]])
	get_tree().quit()

func _ready() -> void:
	Config.test_mode = true
	build_course()
	if "--cal" in OS.get_cmdline_user_args():
		await calibrate()
		return
	var ok_art := Config.assets_ok()
	print("art available: ", ok_art)
	Engine.max_physics_steps_per_frame = 16
	for hz in [60, 30]:
		Engine.physics_ticks_per_second = hz
		Engine.time_scale = 3.0
		await run_flat("@%d Hz" % hz)
		await run_curb("@%d Hz" % hz)
		await run_slope("@%d Hz" % hz)
		await run_jump("@%d Hz" % hz)
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	if ok_art:
		await run_character(Config.TEAM_JIMMY, "jimmy.glb", "Jimmy")
		await run_character(Config.TEAM_NEGATRON, "nummey_villain.glb", "Negatron")
	Engine.time_scale = 1.0
	await run_remote()
	Engine.time_scale = 3.0
	if ok_art:
		await run_real_curb()
	print("MOVE TEST ", "PASS" if fails == 0 else "FAIL")
	get_tree().quit(0 if fails == 0 else 1)
