class_name World
extends Node3D
## Game world + server-authoritative match logic. Node path must be identical on all peers: Main/World.
signal state_changed
signal player_added(id: int)
signal player_died(id: int, killer: int)
signal player_respawned(id: int)
signal player_hurt(id: int, hp: int)
signal hit_event(victim: int, shooter: int, dmg: int, pos: Vector3, killed: bool)
signal loadout_changed(id: int)
signal loadout_pending()

var level: ArenaLevel
var players := {}          # peer id -> Player
var info := {}             # server only: id -> {team, hp, alive, kills, deaths, last_fire}
var team_score := [0, 0]
var kills := {}            # id -> kills (all peers, display)
var deaths := {}
var match_over := false
var winner := -1
var ready_for_peers := false
var spawn_counter := [0, 0]
var bubble_counter := 0
var players_root: Node3D
var bubbles_root: Node3D
var traps_root: Node3D
var traps := []            # server: {id, owner, team, a, b, ends}
var trap_counter := 0
var trap_nodes := {}       # all peers: id -> Node3D

func _ready() -> void:
	name = "World"
	level = ArenaLevel.new()
	level.name = "Level"
	add_child(level)
	players_root = Node3D.new(); players_root.name = "Players"; add_child(players_root)
	bubbles_root = Node3D.new(); bubbles_root.name = "Bubbles"; add_child(bubbles_root)
	traps_root = Node3D.new(); traps_root.name = "Traps"; add_child(traps_root)

func build() -> bool:
	if not level.load_level():
		return false
	level.add_environment()
	return true

# ---------------------------------------------------------------- server
func start_server() -> void:
	multiplayer.peer_connected.connect(_srv_peer_connected)
	multiplayer.peer_disconnected.connect(_srv_peer_disconnected)
	await get_tree().physics_frame
	await get_tree().physics_frame
	ready_for_peers = true
	_srv_peer_connected(1)
	for id in multiplayer.get_peers():
		_srv_peer_connected(id)

const TEAM_AUTO := -1
const SWITCH_COOLDOWN := 10.0   # stops team-switching as a free heal/respawn
const TEAM_CAP := 5
signal team_refused(msg: String)

func _srv_peer_connected(id: int) -> void:
	if not multiplayer.is_server() or info.has(id):
		return
	if not ready_for_peers:
		return  # handled when start_server finishes
	# Players choose a team (request_team). Test runs without --manual_team keep the old auto-join.
	if Config.test_mode and not OS.get_cmdline_user_args().has("--manual_team"):
		_srv_join(id, TEAM_AUTO)

func _team_counts(skip := -1) -> Array:
	var counts := [0, 0]
	for i in info:
		if i != skip:
			counts[info[i].team] += 1
	return counts

## Pure rule: returns {team, msg}; team == -1 means refused (both full). Auto = smaller team (Jimmy on ties).
static func resolve_team(choice: int, counts: Array) -> Dictionary:
	if choice != 0 and choice != 1:
		choice = 0 if counts[0] <= counts[1] else 1
		if counts[choice] >= TEAM_CAP:
			choice = 1 - choice
		if counts[choice] >= TEAM_CAP:
			return {"team": -1, "msg": "Both teams are full."}
		return {"team": choice, "msg": ""}
	if counts[choice] < TEAM_CAP:
		return {"team": choice, "msg": ""}
	var other := 1 - choice
	if counts[other] < TEAM_CAP:
		return {"team": other, "msg": "%s is full - you joined %s." % [Config.TEAM_NAMES[choice], Config.TEAM_NAMES[other]]}
	return {"team": -1, "msg": "Both teams are full."}

## Owner: ask the server for a team (first join, or a later switch).
func request_team(choice: int) -> void:
	if multiplayer.is_server():
		_srv_team_request(1, choice)
	else:
		srv_team.rpc_id(1, choice)

@rpc("any_peer", "reliable")
func srv_team(choice: int) -> void:
	if multiplayer.is_server():
		_srv_team_request(multiplayer.get_remote_sender_id(), choice)

func _srv_team_request(id: int, choice: int) -> void:
	while not ready_for_peers:
		await get_tree().physics_frame
	if id != 1 and not multiplayer.get_peers().has(id):
		return   # left while we waited: don't spawn a ghost
	var r := resolve_team(choice, _team_counts(id))
	if r.team < 0:
		_team_msg(id, r.msg)
		return
	if r.msg != "":
		_team_msg(id, r.msg)
	if info.has(id):
		if info[id].team != r.team:
			var now := Time.get_ticks_msec() / 1000.0
			if not info[id].alive:
				_team_msg(id, "You can switch teams after you respawn.")
			elif now - info[id].get("last_switch", -100.0) < SWITCH_COOLDOWN:
				_team_msg(id, "Wait a few seconds before switching again.")
			else:
				info[id].last_switch = now
				_srv_switch_team(id, r.team)
	else:
		_srv_join(id, r.team)

func _team_msg(id: int, msg: String) -> void:
	if id == 1:
		team_refused.emit(msg)
	else:
		c_team_msg.rpc_id(id, msg)

@rpc("authority", "reliable")
func c_team_msg(msg: String) -> void:
	team_refused.emit(msg)

func _new_info(team: int) -> Dictionary:
	return {"team": team, "hp": Config.MAX_HP, "alive": true, "kills": 0, "deaths": 0, "last_fire": -10.0, "loadout": Loadout.default_loadout(), "pending": {}, "confirmed": false, "max_hp": Config.MAX_HP, "st": {}, "shield_hp": 0, "ult_charge": 0, "gadget_ready": 0.0, "ram_cd": {}}

func _srv_join(id: int, choice: int) -> void:
	if info.has(id):
		return
	var r := resolve_team(choice, _team_counts())
	if r.team < 0:
		_team_msg(id, r.msg)
		return
	var team: int = r.team
	info[id] = _new_info(team)
	var sp := _next_spawn(team)
	# tell the new peer about everyone already here, then everyone about the new one
	for i in info:
		if i != id:
			var p: Player = players.get(i)
			var tr := p.global_transform if p else Transform3D()
			if id != 1:
				c_add_player.rpc_id(id, i, info[i].team, tr)
	c_add_player.rpc(id, team, sp)
	for i in info:
		if i != id and id != 1:
			c_loadout.rpc_id(id, i, Loadout.to_wire(info[i].loadout), info[i].max_hp)
	c_loadout.rpc(id, Loadout.to_wire(info[id].loadout), info[id].max_hp)
	for t in traps:
		c_trap.rpc_id(id, t.id, t.owner, t.team, t.a, t.b)
	c_scores.rpc_id(id, team_score, kills, deaths)

## Server: move a joined player to the other team. Kills/deaths/score untouched; the player respawns fresh at the new side.
func _srv_switch_team(id: int, team: int) -> void:
	var inf: Dictionary = info[id]
	inf.team = team
	inf.st.clear(); inf.shield_hp = 0; inf.ram_cd.clear()
	inf.hp = inf.max_hp
	inf.alive = true
	var sp := _next_spawn(team)
	c_remove_player.rpc(id)
	c_add_player.rpc(id, team, sp)
	c_loadout.rpc(id, Loadout.to_wire(inf.loadout), inf.max_hp)

func _srv_peer_disconnected(id: int) -> void:
	info.erase(id)
	c_remove_player.rpc(id)

func _next_spawn(team: int) -> Transform3D:
	var idx: int = spawn_counter[team]
	spawn_counter[team] += 1
	return level.spawn_point(team, idx)

## Server: respawn transform = most forward team zone with no living enemy within ArenaLevel.ZONE_CLEAR metres.
func _respawn_spawn(id: int) -> Transform3D:
	var team: int = info[id].team
	var enemies := []
	for i in info:
		if info[i].team != team and info[i].alive and players.has(i):
			enemies.append((players[i] as Player).global_position)
	var zone := level.choose_zone(team, enemies)
	var idx: int = spawn_counter[team]
	spawn_counter[team] += 1
	return level.spawn_point(team, idx, zone)

## Called on the owner: ask the server to shoot.
func request_fire_local(origin: Vector3, dir: Vector3, chg := 0.0) -> void:
	if multiplayer.is_server():
		_srv_fire(1, origin, dir, chg)
	else:
		srv_request_fire.rpc_id(1, origin, dir, chg)

@rpc("any_peer", "reliable")
func srv_request_fire(origin: Vector3, dir: Vector3, chg := 0.0) -> void:
	if not multiplayer.is_server():
		return
	_srv_fire(multiplayer.get_remote_sender_id(), origin, dir, chg)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Server: is a timed status (shrink, slow, shield, phase, ult, marked, drone) active on this player?
func srv_has(id: int, kind: String) -> bool:
	return info.has(id) and info[id].st.get(kind, 0.0) > _now()

func srv_set_status(id: int, kind: String, dur: float, val: float = 0.0) -> void:
	if not info.has(id):
		return
	info[id].st[kind] = _now() + dur
	c_status.rpc(id, kind, dur, val)

func srv_weapon(id: int) -> WeaponData:
	var lo: Dictionary = info[id].loadout
	if srv_has(id, "ult"):
		var u := UltimateData.get_ultimate(lo.ultimate)
		if u.p.has("weapon"):
			return WeaponData.get_weapon(u.p.weapon)
	return WeaponData.get_weapon(lo.primary)

func net_ready() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func local_team() -> int:
	if not net_ready():
		return -1
	var me: Player = players.get(multiplayer.get_unique_id())
	return me.team if me else -1

func _srv_fire(id: int, origin: Vector3, dir: Vector3, chg := 0.0) -> void:
	if not info.has(id) or match_over or not info[id].alive or srv_has(id, "phase"):
		return
	var inf: Dictionary = info[id]
	var w := srv_weapon(id)
	var now := _now()
	if now - inf.last_fire < w.fire_interval * 0.8:
		return
	var p: Player = players.get(id)
	if p == null or origin.distance_to(p.global_position) > 4.0 or dir.length() < 0.5:
		return
	inf.last_fire = now
	var dmg := w.damage_for(clampf(chg, 0.0, 1.0))
	var d := dir.normalized()
	var side := d.cross(Vector3.UP).normalized() if absf(d.y) < 0.99 else Vector3.RIGHT
	var up := side.cross(d)
	for i in w.pellets:
		var pd := d
		if w.pellets > 1 and w.spread > 0.0:
			var a := randf() * TAU
			pd = (d + (side * cos(a) + up * sin(a)) * w.spread * sqrt(randf())).normalized()
		bubble_counter += 1
		c_spawn_bubble.rpc(bubble_counter, id, inf.team, w.id, origin, pd, dmg)


## Server: first enemy alive player whose capsule axis is within radius of the segment, 0 if none.
func bubble_test_players(from: Vector3, to: Vector3, radius: float, shooter: int, team: int) -> int:
	var best := 0
	var best_t := 2.0
	for id in players:
		if id == shooter or not info.has(id) or not info[id].alive or info[id].team == team or srv_has(id, "phase"):
			continue
		var p: Player = players[id]
		var a := p.global_position + Vector3(0, 0.3, 0)
		var b := p.global_position + Vector3(0, 1.1, 0)
		var d := _seg_seg_dist(from, to, a, b)
		if d[0] <= 0.35 + radius and d[1] < best_t:
			best_t = d[1]
			best = id
	return best

## returns [distance, t along first segment]
func _seg_seg_dist(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> Array:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 1e-9 and e <= 1e-9:
		return [r.length(), 0.0]
	if a <= 1e-9:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e <= 1e-9:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var denom := a * e - b * b
			if denom > 1e-9:
				s = clampf((b * f - c * e) / denom, 0.0, 1.0)
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	var c1 := p1 + d1 * s
	var c2 := p2 + d2 * t
	return [c1.distance_to(c2), s]

func srv_hit(victim: int, shooter: int, dmg: int, weapon: WeaponData = null, bid := 0, at := Vector3.ZERO) -> void:
	if not info.has(victim) or not info[victim].alive or match_over:
		return
	if srv_has(victim, "phase"):
		return
	var v: Dictionary = info[victim]
	if srv_has(victim, "shrink"):
		dmg = roundi(dmg * GadgetData.get_gadget(&"shrink_ray").f("dmg_mult", 1.0))
	var dmg_in := dmg
	_srv_add_charge(shooter, victim, dmg)
	if v.shield_hp > 0 and srv_has(victim, "shield"):
		var ab := mini(v.shield_hp, dmg)
		v.shield_hp -= ab
		dmg -= ab
		c_status.rpc(victim, "shield", maxf(0.01, v.st.get("shield", 0.0) - _now()), float(v.shield_hp))
		if v.shield_hp <= 0:
			v.st.erase("shield")
			c_status.rpc(victim, "shield", 0.0, 0.0)
	var shown_dmg := dmg_in
	v.hp = maxi(0, v.hp - dmg)
	c_hp.rpc(victim, v.hp)
	var vp: Player = players.get(victim)
	var hp_pos := at if at != Vector3.ZERO else ((vp.global_position + Vector3(0, 1.0, 0)) if vp else Vector3.ZERO)
	c_hit.rpc(victim, shooter, shown_dmg, hp_pos, v.hp <= 0, bid)   # shooter marker / damage number / flinch / feed (server stays authoritative)
	if v.hp > 0:
		if weapon and weapon.slow_time > 0.0:
			srv_set_status(victim, "slow", weapon.slow_time, weapon.slow_factor)
		return
	v.alive = false
	v.deaths += 1
	deaths[victim] = v.deaths
	if info.has(shooter):
		info[shooter].kills += 1
		kills[shooter] = info[shooter].kills
		team_score[info[shooter].team] += 1
	c_died.rpc(victim, shooter)
	c_scores.rpc(team_score, kills, deaths)
	if info.has(shooter) and team_score[info[shooter].team] >= Config.WIN_SCORE:
		match_over = true
		c_match_over.rpc(info[shooter].team)
		get_tree().create_timer(8.0).timeout.connect(_srv_reset_match)
	else:
		get_tree().create_timer(Config.RESPAWN_TIME).timeout.connect(_srv_respawn.bind(victim))

func _srv_add_charge(shooter: int, victim: int, dmg: int) -> void:
	if shooter == victim or not info.has(shooter) or srv_has(shooter, "ult"):
		return
	var inf: Dictionary = info[shooter]
	var cost := int(UltimateData.get_ultimate(inf.loadout.ultimate).f("cost"))
	var nc := mini(cost, inf.ult_charge + dmg)
	if nc != inf.ult_charge:
		inf.ult_charge = nc
		c_ult_charge.rpc(shooter, nc)


func _srv_respawn(id: int) -> void:
	if not info.has(id) or match_over:
		return
	info[id].st.clear()
	info[id].shield_hp = 0
	info[id].ram_cd.clear()
	_srv_apply_loadout(id, false)
	info[id].hp = info[id].max_hp
	info[id].alive = true
	c_respawn.rpc(id, _respawn_spawn(id))

func _srv_reset_match() -> void:
	team_score = [0, 0]
	kills.clear(); deaths.clear()
	match_over = false
	for id in info:
		info[id].kills = 0; info[id].deaths = 0
	c_scores.rpc(team_score, kills, deaths)
	c_match_reset.rpc()
	for id in info:
		_srv_respawn(id)

# ---------------------------------------------------------------- everyone (server -> peers)
@rpc("authority", "call_local", "reliable")
func c_add_player(id: int, team: int, tr: Transform3D) -> void:
	if players.has(id):
		return
	var p := Player.new()
	p.name = str(id)
	p.peer_id = id
	p.team = team
	p.world = self
	p.transform = tr
	players_root.add_child(p)
	players[id] = p
	player_added.emit(id)
	state_changed.emit()

@rpc("authority", "call_local", "reliable")
func c_remove_player(id: int) -> void:
	if players.has(id):
		players[id].name = "_removed%d" % id   # free the node name for an immediate re-add (team switch)
		players[id].queue_free()
		players.erase(id)
	state_changed.emit()

@rpc("authority", "call_local", "reliable")
func c_spawn_bubble(bid: int, shooter: int, team: int, wid: StringName, origin: Vector3, dir: Vector3, dmg: int) -> void:
	var b := Bubble.new()
	b.name = "b%d" % bid
	b.world = self
	b.authoritative = multiplayer.is_server()
	b.setup(WeaponData.get_weapon(wid), shooter, team, origin, dir, dmg)
	bubbles_root.add_child(b)
	var p: Player = players.get(shooter)
	if p:
		p.shoot_pose = 0.4
		p.muzzle_flash(wid)

@rpc("authority", "call_local", "reliable")
func c_hp(id: int, hp: int) -> void:
	if players.has(id):
		players[id].hp = hp
	player_hurt.emit(id, hp)

## Every peer: a hit landed (also after shield absorb). Drives the shooter's hit marker / damage numbers, the victim's flinch + direction indicator and bubble impact bursts.
@rpc("authority", "call_local", "reliable")
func c_hit(victim: int, shooter: int, dmg: int, pos: Vector3, killed: bool, bid := 0) -> void:
	var vp: Player = players.get(victim)
	var sp: Player = players.get(shooter)
	if vp:
		vp.flinch(sp.global_position if sp else Vector3.ZERO)
	if bid != 0 and bubbles_root:
		var bn := bubbles_root.get_node_or_null("b%d" % bid)
		if bn:
			bn.queue_free()
	var tc: Color = Config.TEAM_COLORS[sp.team] if sp else Color.WHITE
	Fx.burst(self, pos, [tc, Color.WHITE], 10, 3.0, 0.06, 0.45, 4.0)
	hit_event.emit(victim, shooter, dmg, pos, killed)

@rpc("authority", "call_local", "reliable")
func c_died(id: int, killer: int) -> void:
	if players.has(id):
		players[id].set_dead()
		players[id].hp = 0
	player_died.emit(id, killer)

@rpc("authority", "call_local", "reliable")
func c_respawn(id: int, tr: Transform3D) -> void:
	if players.has(id):
		players[id].set_alive_at(tr)
	player_respawned.emit(id)

@rpc("authority", "call_local", "reliable")
func c_scores(ts: Array, k: Dictionary, d: Dictionary) -> void:
	team_score = ts
	kills = k
	deaths = d
	state_changed.emit()

@rpc("authority", "call_local", "reliable")
func c_match_over(team: int) -> void:
	match_over = true
	winner = team
	state_changed.emit()

@rpc("authority", "call_local", "reliable")
func c_match_reset() -> void:
	match_over = false
	winner = -1
	state_changed.emit()

# ---------------------------------------------------------------- loadouts / gadgets / ultimates (server)
## Owner: choose a loadout. First confirm applies immediately (first spawn); later ones apply on next respawn.
func request_loadout(lo: Dictionary) -> void:
	var wire := Loadout.to_wire(lo)
	if multiplayer.is_server():
		_srv_set_loadout(1, wire)
	else:
		srv_loadout.rpc_id(1, wire)

@rpc("any_peer", "reliable")
func srv_loadout(wire: Dictionary) -> void:
	if multiplayer.is_server():
		_srv_set_loadout(multiplayer.get_remote_sender_id(), wire)

func _srv_set_loadout(id: int, wire: Dictionary) -> void:
	if not info.has(id):
		return
	var inf: Dictionary = info[id]
	inf.pending = Loadout.sanitize(wire)
	c_pending.rpc_id(id, Loadout.to_wire(inf.pending))
	if not inf.confirmed:
		inf.confirmed = true
		_srv_apply_loadout(id, true)

func _srv_apply_loadout(id: int, heal: bool) -> void:
	var inf: Dictionary = info[id]
	var lo: Dictionary = inf.pending if not inf.pending.is_empty() else inf.loadout
	if lo.ultimate != inf.loadout.ultimate:
		inf.ult_charge = 0
		c_ult_charge.rpc(id, 0)
	inf.loadout = lo
	inf.max_hp = Loadout.max_hp(lo)
	inf.gadget_ready = 0.0
	if heal:
		inf.hp = inf.max_hp
		c_hp.rpc(id, inf.hp)
	c_loadout.rpc(id, Loadout.to_wire(lo), inf.max_hp)

func request_gadget(origin: Vector3, dir: Vector3) -> void:
	if multiplayer.is_server():
		_srv_gadget(1, origin, dir)
	else:
		srv_gadget.rpc_id(1, origin, dir)

@rpc("any_peer", "reliable")
func srv_gadget(origin: Vector3, dir: Vector3) -> void:
	if multiplayer.is_server():
		_srv_gadget(multiplayer.get_remote_sender_id(), origin, dir)

func _srv_gadget(id: int, origin: Vector3, dir: Vector3) -> void:
	if not info.has(id) or match_over or not info[id].alive or srv_has(id, "phase"):
		return
	var inf: Dictionary = info[id]
	var p: Player = players.get(id)
	if p == null or _now() < inf.gadget_ready or origin.distance_to(p.global_position) > 4.0 or dir.length() < 0.5:
		return
	var g := GadgetData.get_gadget(inf.loadout.gadget)
	inf.gadget_ready = _now() + g.f("cooldown") * 0.9
	var d := dir.normalized()
	match g.id:
		&"shrink_ray":
			var end := origin + d * g.f("range")
			var q := PhysicsRayQueryParameters3D.create(origin, end, 1)
			var r := get_world_3d().direct_space_state.intersect_ray(q)
			if r:
				end = r.position
			var victim := bubble_test_players(origin, end, 0.3, id, inf.team)
			if victim != 0:
				srv_set_status(victim, "shrink", g.f("duration"))
			c_beam.rpc(id, origin, end)
		&"energy_shield":
			inf.shield_hp = int(g.f("absorb"))
			srv_set_status(id, "shield", g.f("duration"), float(inf.shield_hp))
		&"laser_trap":
			var mine := traps.filter(func(t): return t.owner == id)
			if mine.size() >= int(g.f("max_traps")):
				_srv_remove_trap(mine[0].id)
			var fwd := Vector3(d.x, 0, d.z)
			fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
			var c := p.global_position + fwd * g.f("dist")
			var gq := PhysicsRayQueryParameters3D.create(c + Vector3(0, 2, 0), c - Vector3(0, 6, 0), 1)
			var gr := get_world_3d().direct_space_state.intersect_ray(gq)
			if gr:
				c.y = gr.position.y
			var perp := fwd.cross(Vector3.UP).normalized()
			var h := Vector3(0, 0.6, 0)
			trap_counter += 1
			var t := {"id": trap_counter, "owner": id, "team": inf.team, "a": c + h - perp * g.f("width") * 0.5, "b": c + h + perp * g.f("width") * 0.5, "ends": _now() + g.f("life"), "dmg": int(g.f("damage"))}
			traps.append(t)
			c_trap.rpc(t.id, id, inf.team, t.a, t.b)
		&"drone":
			srv_set_status(id, "drone", g.f("duration"))
			for eid in info:
				if info[eid].team != inf.team and info[eid].alive and players.has(eid) and players[eid].global_position.distance_to(p.global_position) <= g.f("radius"):
					srv_set_status(eid, "marked", g.f("duration"), float(inf.team))
		&"power_phase":
			srv_set_status(id, "phase", g.f("duration"))

func _srv_remove_trap(tid: int) -> void:
	for i in traps.size():
		if traps[i].id == tid:
			traps.remove_at(i)
			break
	c_trap_remove.rpc(tid)

func request_ultimate() -> void:
	if multiplayer.is_server():
		_srv_ultimate(1)
	else:
		srv_ultimate.rpc_id(1)

@rpc("any_peer", "reliable")
func srv_ultimate() -> void:
	if multiplayer.is_server():
		_srv_ultimate(multiplayer.get_remote_sender_id())

func _srv_ultimate(id: int) -> void:
	if not info.has(id) or match_over or not info[id].alive or srv_has(id, "ult"):
		return
	var inf: Dictionary = info[id]
	var u := UltimateData.get_ultimate(inf.loadout.ultimate)
	if inf.ult_charge < int(u.f("cost")):
		return
	inf.ult_charge = 0
	c_ult_charge.rpc(id, 0)
	srv_set_status(id, "ult", u.f("duration"))

func _physics_process(_d: float) -> void:
	if not net_ready() or not multiplayer.is_server() or match_over:
		return
	var now := _now()
	for t in traps.duplicate():
		if now > t.ends:
			_srv_remove_trap(t.id)
			continue
		for id in players:
			if not info.has(id) or not info[id].alive or info[id].team == t.team or srv_has(id, "phase"):
				continue
			var p: Player = players[id]
			var dd := _seg_seg_dist(t.a, t.b, p.global_position + Vector3(0, 0.1, 0), p.global_position + Vector3(0, 1.1, 0))
			if dd[0] <= 0.3:
				_srv_remove_trap(t.id)
				srv_hit(id, t.owner, t.dmg)
				break
	for id in info:
		if not info[id].alive or not srv_has(id, "ult"):
			continue
		var u := UltimateData.get_ultimate(info[id].loadout.ultimate)
		if u.id != &"goddard_scooter" or not players.has(id):
			continue
		var me: Player = players[id]
		for eid in info:
			if info[eid].team == info[id].team or not info[eid].alive or not players.has(eid) or info[id].ram_cd.get(eid, 0.0) > now:
				continue
			var d3: Vector3 = players[eid].global_position - me.global_position
			if Vector2(d3.x, d3.z).length() <= u.f("ram_radius") and absf(d3.y) < 1.6:
				info[id].ram_cd[eid] = now + u.f("ram_interval")
				srv_hit(eid, id, int(u.f("ram_damage")))

# ---------------------------------------------------------------- everyone: loadout / status / fx
@rpc("authority", "call_local", "reliable")
func c_loadout(id: int, wire: Dictionary, mhp: int) -> void:
	if players.has(id):
		players[id].set_loadout(wire, mhp)
		if players[id].alive and players[id].hp > mhp:
			players[id].hp = mhp
	loadout_changed.emit(id)

@rpc("authority", "call_local", "reliable")
func c_pending(wire: Dictionary) -> void:
	var me: Player = players.get(multiplayer.get_unique_id())
	if me:
		me.pending_loadout = Loadout.sanitize(wire)
	loadout_pending.emit()

@rpc("authority", "call_local", "reliable")
func c_status(id: int, kind: String, dur: float, val: float) -> void:
	if players.has(id):
		players[id].set_status(kind, dur, val)

@rpc("authority", "call_local", "reliable")
func c_ult_charge(id: int, v: int) -> void:
	if players.has(id):
		players[id].ult_charge = v

@rpc("authority", "call_local", "unreliable")
func c_beam(_id: int, a: Vector3, b: Vector3) -> void:
	var mi := Fx.beam(0.07, Color(0.5, 1.0, 0.4, 0.8))
	traps_root.add_child(mi)
	Fx.place_beam(mi, a, b)
	get_tree().create_timer(0.25).timeout.connect(mi.queue_free)

@rpc("authority", "call_local", "reliable")
func c_trap(tid: int, _owner: int, team: int, a: Vector3, b: Vector3) -> void:
	var col := Color(1.0, 0.15, 0.15, 0.9) if team == 1 else Color(0.2, 0.9, 1.0, 0.9)
	var root := Node3D.new()
	traps_root.add_child(root)
	var mi := Fx.beam(0.05, col)
	root.add_child(mi)
	Fx.place_beam(mi, a, b)
	for end in [a, b]:   # emitter posts (the wire sits 0.6 m above the floor)
		var post := WeaponModel.pylon(0.6, Color(col.r, col.g, col.b))
		root.add_child(post)
		post.global_position = end - Vector3(0, 0.6, 0)
	trap_nodes[tid] = root

@rpc("authority", "call_local", "reliable")
func c_trap_remove(tid: int) -> void:
	if trap_nodes.has(tid):
		trap_nodes[tid].queue_free()
		trap_nodes.erase(tid)
