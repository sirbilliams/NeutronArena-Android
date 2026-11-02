class_name BotBrain
extends RefCounted
## One bot's AI. Server only. Thinks at THINK_HZ (target pick, LOS rays, route/steering, gadget use) and every physics
## frame turns the aim smoothly and writes Player.bot_in, so the Player moves/fires through the normal _local_step path.
const THINK_HZ := 10.0
const DIFFS := {
	"easy": {"react": 0.6, "err": 0.07, "turn": 4.5, "lead": 0.0, "duty": 0.5, "sight": 45.0, "jump": 0.03},
	"normal": {"react": 0.35, "err": 0.035, "turn": 8.0, "lead": 0.5, "duty": 0.8, "sight": 60.0, "jump": 0.06},
	"hard": {"react": 0.15, "err": 0.015, "turn": 14.0, "lead": 1.0, "duty": 1.0, "sight": 75.0, "jump": 0.1},
}
var id := 0
var world: World
var nav: BotNav
var player: Player
var cfg: Dictionary = DIFFS["normal"]
var think_t := randf() * 0.1
var q := PhysicsRayQueryParameters3D.new()
# decisions (written by think, consumed by apply)
var move_dir := Vector2.ZERO     # world xz, length 0..1
var want_mvt := false
var jump_req := false
var jump_hold := 0.0
var fire_want := false
var target_id := 0
var target_since := 0.0
var target_vis := false
var last_seen_t := -100.0
var last_seen := Vector3.ZERO
var tpos := Vector3.ZERO
var tvel := Vector3.ZERO
var tprev := Vector3.ZERO
var tprev_t := 0.0
var aim_err := Vector3.ZERO
var strafe := 1.0
var strafe_until := 0.0
var burst_on := true
var burst_until := 0.0
var retreat_until := 0.0
var retreat_cool := 0.0
var lateral := randf_range(-2.0, 2.0)
var stuck := 0.0
var last_pos := Vector3.ZERO
var unstick_until := 0.0
var unstick_dir := Vector2.ZERO
var was_alive := true
var yaw := 0.0
var pitch := 0.0
var prev_hp := 100
var hurt_t := -100.0

func set_difficulty(d: String) -> void:
	cfg = DIFFS.get(d, DIFFS["normal"])

func tick(dt: float, now: float) -> void:
	var p := player
	if not p.alive or world.match_over or not world.info.has(id):
		if was_alive:
			was_alive = false
			target_id = 0
			p.bot_in.mv = Vector2.ZERO
			p.bot_in.fire = false
			p.bot_in.mvt = false
		return
	if not was_alive:
		was_alive = true
		yaw = p.cam_yaw
		pitch = 0.0
		last_pos = p.global_position
		stuck = 0.0
		prev_hp = p.hp
	think_t -= dt
	if think_t <= 0.0:
		think_t += 1.0 / THINK_HZ
		_think(now)
	_apply(dt, now)

# ---------------------------------------------------------------- helpers
func _ray(from: Vector3, to: Vector3) -> Dictionary:
	q.from = from
	q.to = to
	q.collision_mask = 1
	return player.get_world_3d().direct_space_state.intersect_ray(q)

static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

## free distance along a flat direction at knee-to-chest height
func _clear(pos: Vector3, d: Vector2, length: float) -> float:
	var from := pos + Vector3(0, 0.7, 0)
	var r := _ray(from, from + Vector3(d.x, 0, d.y) * length)
	return length if r.is_empty() else from.distance_to(r.position)

func _weapon_range(w: WeaponData) -> float:
	return minf(w.projectile_speed * w.lifetime * 0.75, cfg.sight)

# ---------------------------------------------------------------- think (10 Hz)
func _think(now: float) -> void:
	var p := player
	var pos := p.global_position
	var pos2 := _flat(pos)
	var inf: Dictionary = world.info[id]
	var w := p.effective_weapon()
	var rng := _weapon_range(w)
	if p.hp < prev_hp:
		hurt_t = now
	prev_hp = p.hp
	# --- target: nearest enemy with a clear line of sight
	var cands := []
	for eid in world.players:
		if not world.info.has(eid) or world.info[eid].team == inf.team or not world.info[eid].alive or world.srv_has(eid, "phase"):
			continue
		var e: Player = world.players[eid]
		var dd := pos2.distance_to(_flat(e.global_position))
		var vdist := absf(e.global_position.y - pos.y)
		if dd < cfg.sight and vdist < 25.0:
			cands.append([dd, eid])
	cands.sort()
	var seen := 0
	var eye := pos + Vector3(0, 1.2, 0)
	for c in cands.slice(0, 3):
		var e2: Player = world.players[c[1]]
		var ch := e2.global_position + Vector3(0, 0.9, 0)
		var r := _ray(eye, ch)
		if r.is_empty() or eye.distance_to(r.position) > eye.distance_to(ch) - 0.4:
			seen = c[1]
			break
	target_vis = seen != 0
	if target_vis:
		if seen != target_id:
			target_id = seen
			target_since = now
			tprev = world.players[seen].global_position
			tprev_t = now
			tvel = Vector3.ZERO
		var tp: Vector3 = world.players[seen].global_position
		var span := now - tprev_t
		if span > 0.05:
			tvel = tvel.lerp((tp - tprev) / span, 0.5)
			tprev = tp
			tprev_t = now
		tpos = tp
		last_seen_t = now
		last_seen = tp
		aim_err = Vector3(randfn(0, 1), randfn(0, 0.6), randfn(0, 1)) * cfg.err   # angular error, scaled by distance in apply
	elif now - last_seen_t > 2.5:
		target_id = 0
	var dist := 0.0
	var to_t := Vector2.ZERO
	if target_vis:
		var tv := tpos - pos
		dist = _flat(tv).length()
		to_t = _flat(tv).normalized()
	# --- retreat when badly hurt (3-5 s, then a cool-down so it still fights)
	var hp_frac := float(p.hp) / maxf(p.max_hp, 1)
	if hp_frac < 0.3 and now > retreat_cool and now > retreat_until and target_vis:
		retreat_until = now + randf_range(3.0, 5.0)
		retreat_cool = retreat_until + 8.0
	var retreating := now < retreat_until
	# --- movement intent
	var pref := clampf(rng * 0.5, 6.0, 22.0)
	if now > strafe_until:
		strafe = -strafe if randf() < 0.8 else strafe
		strafe_until = now + randf_range(0.7, 1.7)
	# mode objective: flag / hill goal (null = TDM / Gun Game: follow the street towards the enemy and fight)
	var goal: Variant = world.mode.bot_goal(id, inf.team, pos)
	var rushing := world.mode.bot_rush(id)
	var route_dir := _route_dir(pos2, retreating, _flat(goal) if goal != null else Vector2.INF)
	var intent := route_dir
	want_mvt = false
	var in_combat := target_vis and dist < rng
	if target_vis:
		var perp := Vector2(-to_t.y, to_t.x) * strafe
		if retreating:
			intent = (-to_t * 0.8 + perp * 0.5).normalized()
			want_mvt = true
		elif rushing:
			intent = route_dir     # flag carrier: keep running, shoot on the way
			want_mvt = true
		elif goal != null and _flat(goal).distance_to(pos2) < 6.0 and dist > pref * 0.55:
			intent = perp          # holding the hill / flag stand: strafe instead of chasing out
		elif dist > rng * 0.85:
			intent = to_t if dist < 35.0 else route_dir
		elif dist > pref * 1.3:
			intent = (to_t * 0.7 + perp * 0.4).normalized()
		elif dist < pref * 0.55:
			intent = (-to_t * 0.6 + perp * 0.6).normalized()
		else:
			intent = perp
	elif now - last_seen_t < 2.5 and last_seen != Vector3.ZERO:
		var lv := _flat(last_seen) - pos2
		intent = lv.normalized() if lv.length() > 2.0 else route_dir
	else:
		want_mvt = true    # travelling: sprint if we can
	# --- obstacle steering (whiskers) + stuck handling
	var moved := pos.distance_to(last_pos)
	last_pos = pos
	if intent.length() > 0.1 and p.is_on_floor() and moved < 0.12:
		stuck += 0.1
	else:
		stuck = maxf(0.0, stuck - 0.2)
	if now < unstick_until:
		intent = unstick_dir
	else:
		intent = _steer(pos, intent)
		if stuck > 0.7:
			unstick_until = now + 0.9
			var a := randf_range(1.2, 2.2) * (1.0 if randf() < 0.5 else -1.0)
			unstick_dir = intent.rotated(a)
			stuck = 0.3
			jump_req = true
	if stuck > 0.4 and not jump_req:
		jump_req = true
	if in_combat and randf() < cfg.jump:
		jump_req = true
	if jump_req:
		jump_hold = 0.35
	# movement abilities
	match p.movement.id:
		&"jetpack":
			want_mvt = stuck > 0.3 or (in_combat and p.fuel > 60.0 and randf() < 0.15) or (p.fuel > 85.0 and not target_vis and randf() < 0.02)
		&"goof_boots":
			want_mvt = false
		&"grapple", &"bubble_float", &"none":
			want_mvt = false
	move_dir = intent
	# --- fire decision
	fire_want = false
	if in_combat and now - target_since >= cfg.react:
		if now > burst_until:
			burst_on = randf() < cfg.duty
			burst_until = now + randf_range(0.5, 1.2)
		fire_want = burst_on
	# --- gadgets / ultimate
	_use_gear(now, in_combat, dist, hp_frac, retreating)

## Direction to follow the street. `goal` (world xz) set: walk the street towards it, straight at it when close.
func _route_dir(pos2: Vector2, back: bool, goal := Vector2.INF) -> Vector2:
	var pr := nav.project(pos2)
	var sgn := 1.0 if player.team == Config.TEAM_JIMMY else -1.0
	if goal != Vector2.INF and not back:
		var gd := goal - pos2
		if gd.length() < 14.0 and (pr.d <= 10.0 or gd.length() < 8.0):
			return gd.normalized() if gd.length() > 1.5 else Vector2.ZERO
		var gs: float = nav.project(goal).s
		if absf(gs - pr.s) < 1.0:
			return gd.normalized()
		sgn = 1.0 if gs > pr.s else -1.0
		if pr.d > 10.0:
			return (nav.point_at(pr.s) - pos2).normalized()
		var s2: float = pr.s + sgn * minf(9.0, absf(gs - pr.s))
		var wp2 := nav.point_at(s2)
		return (wp2 - pos2).normalized()
	if back:
		sgn = -sgn
	if pr.d > 10.0:
		var back_pt := nav.point_at(pr.s)
		return (back_pt - pos2).normalized()
	var s: float = pr.s + sgn * 9.0
	var wp := nav.point_at(s)
	var tang := nav.tangent_at(s)
	wp += Vector2(-tang.y, tang.x) * lateral
	var v := wp - pos2
	# at the far end of the route: stand and wander
	if (sgn > 0.0 and pr.s > nav.total - 6.0) or (sgn < 0.0 and pr.s < 6.0):
		return Vector2.ZERO
	return v.normalized()

## Bend the wanted direction around walls using three whisker rays.
func _steer(pos: Vector3, d: Vector2) -> Vector2:
	if d.length() < 0.1:
		return d
	var f := _clear(pos, d, 2.4)
	if f >= 2.3:
		return d
	var l := _clear(pos, d.rotated(0.8), 2.4)
	var r := _clear(pos, d.rotated(-0.8), 2.4)
	if l < 1.0 and r < 1.0:
		return d.rotated(1.6 if l >= r else -1.6)   # cornered: slide along
	return d.rotated(0.9 if l > r else -0.9)

func _use_gear(now: float, in_combat: bool, dist: float, hp_frac: float, retreating: bool) -> void:
	var p := player
	var inf: Dictionary = world.info[id]
	var aimd := Vector3(move_dir.x, 0, move_dir.y)
	if target_vis:
		aimd = (tpos - p.global_position).normalized()
	if aimd.length() < 0.1:
		return
	if p.ult_charge >= int(p.ultimate.f("cost")) and in_combat and not p.has_status("ult") and dist < 45.0:
		p.try_ultimate()
	if p.gadget_cd > 0.0 or p.has_status("phase"):
		return
	match p.gadget.id:
		&"shrink_ray":
			if in_combat and dist < p.gadget.f("range") * 0.9:
				p.try_gadget(aimd)
		&"energy_shield":
			if in_combat and (now - hurt_t < 1.0 or dist < 15.0):
				p.try_gadget(aimd)
		&"power_phase":
			if retreating and hp_frac < 0.35:
				p.try_gadget(aimd)
		&"laser_trap":
			if (retreating or (target_vis and dist > 12.0 and randf() < 0.05)) or (not target_vis and randf() < 0.01):
				p.try_gadget(aimd)
		&"drone":
			if not target_vis and randf() < 0.03:
				p.try_gadget(aimd)

# ---------------------------------------------------------------- apply (every physics frame)
func _apply(dt: float, now: float) -> void:
	var p := player
	var bi: Dictionary = p.bot_in
	var pos := p.global_position
	var muzzle := p.muzzle()
	var want_yaw := yaw
	var want_pitch := 0.0
	var turn: float = 6.0
	var aim_pt := Vector3.ZERO
	var have_aim := false
	if target_id != 0 and world.players.has(target_id) and (target_vis or now - last_seen_t < 0.6):
		var tp: Vector3 = world.players[target_id].global_position
		var dist := muzzle.distance_to(tp)
		var w := p.effective_weapon()
		var t_fly := dist / maxf(w.projectile_speed, 1.0)
		aim_pt = tp + Vector3(0, 0.85, 0) + tvel * t_fly * cfg.lead
		aim_pt.y += 0.5 * w.gravity * t_fly * t_fly   # arcing weapons: aim above
		aim_pt += aim_err * dist
		var v := aim_pt - muzzle
		want_yaw = atan2(-v.x, -v.z)
		want_pitch = asin(clampf(v.y / maxf(v.length(), 0.001), -1.0, 1.0))
		turn = cfg.turn
		have_aim = true
	elif move_dir.length() > 0.1:
		want_yaw = atan2(-move_dir.x, -move_dir.y)
	var step := turn * dt
	yaw += clampf(angle_difference(yaw, want_yaw), -step, step)
	pitch += clampf(want_pitch - pitch, -step, step)
	p.cam_yaw = yaw
	p.cam_pitch = pitch
	var fwd := Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
	bi.aim = fwd
	# movement relative to the (smoothed) camera yaw
	var local := Vector3(move_dir.x, 0, move_dir.y).rotated(Vector3.UP, -yaw)
	bi.mv = Vector2(local.x, local.z).limit_length(1.0)
	# fire only when roughly on target
	var fire := false
	if fire_want and have_aim:
		var to_aim := (aim_pt - muzzle).normalized()
		var dev := acos(clampf(fwd.dot(to_aim), -1.0, 1.0))
		fire = dev < 0.12 + 0.6 / maxf(muzzle.distance_to(aim_pt), 3.0)
	var w2 := p.effective_weapon()
	if w2.charge_time > 0.0 and fire and p.charge >= 0.75:
		fire = false    # release the charged shot
	bi.fire = fire
	bi.mvt = want_mvt and bi.mv.length() > 0.1 or (p.movement.id == &"jetpack" and want_mvt)
	if jump_req:
		bi.jump = true
		jump_req = false
	jump_hold = maxf(0.0, jump_hold - dt)
	bi.jump_held = jump_hold > 0.0 or (p.movement.id == &"jetpack" and want_mvt)
