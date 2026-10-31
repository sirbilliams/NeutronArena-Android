class_name World
extends Node3D
## Game world + server-authoritative match logic. Node path must be identical on all peers: Main/World.
signal state_changed
signal player_added(id: int)
signal player_died(id: int, killer: int)
signal player_respawned(id: int)
signal player_hurt(id: int, hp: int)

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

func _ready() -> void:
	name = "World"
	level = ArenaLevel.new()
	level.name = "Level"
	add_child(level)
	players_root = Node3D.new(); players_root.name = "Players"; add_child(players_root)
	bubbles_root = Node3D.new(); bubbles_root.name = "Bubbles"; add_child(bubbles_root)

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

func _srv_peer_connected(id: int) -> void:
	if not multiplayer.is_server() or info.has(id):
		return
	if not ready_for_peers:
		return  # handled when start_server finishes
	var counts := [0, 0]
	for i in info:
		counts[info[i].team] += 1
	var team: int = Config.TEAM_JIMMY if counts[0] <= counts[1] else Config.TEAM_NEGATRON
	info[id] = {"team": team, "hp": Config.MAX_HP, "alive": true, "kills": 0, "deaths": 0, "last_fire": -10.0, "weapon": &"bubble_gun"}
	var sp := _next_spawn(team)
	# tell the new peer about everyone already here, then everyone about the new one
	for i in info:
		if i != id:
			var p: Player = players.get(i)
			var tr := p.global_transform if p else Transform3D()
			if id != 1:
				c_add_player.rpc_id(id, i, info[i].team, tr)
	c_add_player.rpc(id, team, sp)
	c_scores.rpc_id(id, team_score, kills, deaths)

func _srv_peer_disconnected(id: int) -> void:
	info.erase(id)
	c_remove_player.rpc(id)

func _next_spawn(team: int) -> Transform3D:
	var idx: int = spawn_counter[team]
	spawn_counter[team] += 1
	return level.spawn_point(team, idx)

## Called on the owner: ask the server to shoot.
func request_fire_local(origin: Vector3, dir: Vector3) -> void:
	if multiplayer.is_server():
		_srv_fire(1, origin, dir)
	else:
		srv_request_fire.rpc_id(1, origin, dir)

@rpc("any_peer", "reliable")
func srv_request_fire(origin: Vector3, dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	_srv_fire(multiplayer.get_remote_sender_id(), origin, dir)

func _srv_fire(id: int, origin: Vector3, dir: Vector3) -> void:
	if not info.has(id) or match_over or not info[id].alive:
		return
	var inf: Dictionary = info[id]
	var w := WeaponData.get_weapon(inf.weapon)
	var now := Time.get_ticks_msec() / 1000.0
	if now - inf.last_fire < w.fire_interval * 0.8:
		return
	var p: Player = players.get(id)
	if p == null or origin.distance_to(p.global_position) > 4.0 or dir.length() < 0.5:
		return
	inf.last_fire = now
	bubble_counter += 1
	c_spawn_bubble.rpc(bubble_counter, id, inf.team, w.id, origin, dir.normalized())

## Server: first enemy alive player whose capsule axis is within radius of the segment, 0 if none.
func bubble_test_players(from: Vector3, to: Vector3, radius: float, shooter: int, team: int) -> int:
	var best := 0
	var best_t := 2.0
	for id in players:
		if id == shooter or not info.has(id) or not info[id].alive or info[id].team == team:
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

func srv_hit(victim: int, shooter: int, dmg: int) -> void:
	if not info.has(victim) or not info[victim].alive or match_over:
		return
	var v: Dictionary = info[victim]
	v.hp = maxi(0, v.hp - dmg)
	c_hp.rpc(victim, v.hp)
	if v.hp > 0:
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

func _srv_respawn(id: int) -> void:
	if not info.has(id) or match_over:
		return
	info[id].hp = Config.MAX_HP
	info[id].alive = true
	c_respawn.rpc(id, _next_spawn(info[id].team))

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
		players[id].queue_free()
		players.erase(id)
	state_changed.emit()

@rpc("authority", "call_local", "reliable")
func c_spawn_bubble(bid: int, shooter: int, team: int, wid: StringName, origin: Vector3, dir: Vector3) -> void:
	var b := Bubble.new()
	b.name = "b%d" % bid
	b.world = self
	b.authoritative = multiplayer.is_server()
	b.setup(WeaponData.get_weapon(wid), shooter, team, origin, dir)
	bubbles_root.add_child(b)
	var p: Player = players.get(shooter)
	if p:
		p.shoot_pose = 0.4

@rpc("authority", "call_local", "reliable")
func c_hp(id: int, hp: int) -> void:
	if players.has(id):
		players[id].hp = hp
	player_hurt.emit(id, hp)

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
