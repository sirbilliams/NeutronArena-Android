extends Node
## Headless multiplayer test. Roles (3 processes on localhost): server, client, observer.
## See tests/run_net_test.sh
var main: Node
var role := ""
var world: World
var fails: Array[String] = []
var ev := {"hit_mine": 0, "hit_kill": 0, "hit_on_me": 0, "hurt": 0, "died": 0, "respawn": 0, "over": false, "reset": false}

func check(cond: bool, msg: String) -> void:
	print("  [%s] %s" % ["ok" if cond else "FAIL", msg])
	if not cond:
		fails.append(msg)

func wait_for(cb: Callable, timeout := 20.0) -> bool:
	var t := 0.0
	while t < timeout:
		if cb.call():
			return true
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	return false

func finish() -> void:
	print("%s: %s" % [role.to_upper(), "PASS" if fails.is_empty() else "FAIL " + str(fails)])
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(0 if fails.is_empty() else 1)

func _ready() -> void:
	match role:
		"server": _server()
		"client": _client()
		"observer": _observer()

func _expected_players() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--expect="): return int(a.substr(9))
	return 3

# ---------------------------------------------------------------- server
func _server() -> void:
	check(await main.start_host(), "host started")
	world = main.world
	var exp := _expected_players()
	world.hit_event.connect(func(_v, sh, _d, pos, killed): if sh == 1 and pos != Vector3.ZERO: ev.hit_mine += 1; ev.hit_kill += int(killed))
	var manual := OS.get_cmdline_user_args().has("--manual_team")
	_team_rule_checks()
	if manual:
		world.request_team(Config.TEAM_JIMMY)
	check(await wait_for(func(): return world.players.size() >= exp, 40.0), "%d players joined" % exp)
	var me: Player = world.players[1]
	check(me.team == Config.TEAM_JIMMY, "host is Jimmy")
	var teams := [0, 0]
	for p in world.players.values(): teams[p.team] += 1
	if manual:
		check(teams == [2, 1], "explicit choices honoured: host+observer Jimmy, client Negatron %s" % str(teams))
	check(absi(teams[0] - teams[1]) <= 1, "teams balanced %s" % str(teams))
	var victim_id := 0
	for id in world.players:
		if world.players[id].team == Config.TEAM_NEGATRON:
			victim_id = id
			break
	check(victim_id != 0, "a Negatron player exists")
	var victim: Player = world.players[victim_id]
	var spawn_dist := victim.global_position.distance_to(world.level.raw_to_world(ArenaLevel.MUSEUM_CENTER))
	check(spawn_dist < 15.0, "Negatron spawned at museum plaza (%.1f m)" % spawn_dist)
	var my_spawn := me.global_position.distance_to(world.level.raw_to_world(ArenaLevel.CANDY_CENTER))
	check(my_spawn < 15.0, "Jimmy spawned at candy bar (%.1f m)" % my_spawn)
	await get_tree().create_timer(3.0).timeout  # client walks 1 s then stops, positions sync
	# teleport next to the victim and shoot it
	me.global_position = victim.global_position + Vector3(0, 0.1, -6.0)
	me.velocity = Vector3.ZERO
	await get_tree().create_timer(0.6).timeout
	var dmg := WeaponData.get_weapon(&"bubble_gun").damage
	_shoot(me, victim)
	await get_tree().create_timer(0.8).timeout
	check(world.info[victim_id].hp == Config.MAX_HP - dmg, "first hit -> hp %d (server)" % world.info[victim_id].hp)
	for i in 4:
		await get_tree().create_timer(0.4).timeout
		_shoot(me, victim)
	await get_tree().create_timer(0.8).timeout
	check(not world.info[victim_id].alive, "victim dead after 5 hits")
	check(ev.hit_mine >= 5 and ev.hit_kill == 1, "shooter received hit_event for each hit (%d) incl. one kill flag" % ev.hit_mine)
	check(world.team_score[0] == 1 and world.team_score[1] == 0, "score Jimmy 1 - 0 (%s)" % str(world.team_score))
	check(world.info[1].kills == 1, "host has 1 kill")
	await get_tree().create_timer(Config.RESPAWN_TIME + 0.4).timeout
	check(world.info[victim_id].alive and world.info[victim_id].hp == Config.MAX_HP, "victim respawned with full hp")
	var zd := 1e9
	for z in world.level.zones[Config.TEAM_NEGATRON]:
		zd = minf(zd, victim.global_position.distance_to(world.level.raw_to_world(z.raw)))
	check(zd < 15.0, "respawned at a Negatron zone (%.1f m)" % zd)
	# friendly-fire / no self-damage is implicit (bubble ignores shooter + same team)
	# client retaliates: wait for Jimmy to be killed by the client
	check(await wait_for(func(): return world.team_score[1] >= 1, 25.0), "client killed host (client->server fire path)")
	check(await wait_for(func(): return world.info[1].alive, 8.0), "host respawned")
	# match end + reset
	world.team_score[0] = Config.WIN_SCORE - 1
	world.info[1].kills = 0
	world.srv_hit(victim_id, 1, 1000)
	await get_tree().create_timer(0.5).timeout
	check(world.match_over and world.winner == 0, "first to %d wins (match_over)" % Config.WIN_SCORE)
	check(await wait_for(func(): return not world.match_over and world.team_score == [0, 0], 12.0), "match reset: scores 0-0")
	await get_tree().create_timer(1.0).timeout
	check(world.info[victim_id].alive, "all players alive after reset")
	if OS.get_cmdline_user_args().has("--manual_team"):
		var oid := 0
		for id in world.players:
			if id != 1 and world.info[id].team == Config.TEAM_JIMMY:
				oid = id
		check(oid != 0, "a second Jimmy peer exists for the switch test")
		world.info[oid].kills = 3
		var sc: Array = world.team_score.duplicate()
		world._srv_team_request(oid, Config.TEAM_NEGATRON)
		await get_tree().create_timer(0.5).timeout
		check(world.info[oid].team == Config.TEAM_NEGATRON and world.players[oid].team == Config.TEAM_NEGATRON, "switch: peer moved to Negatron (server)")
		check(world.info[oid].kills == 3 and world.info[oid].deaths == 0 and world.team_score == sc, "switch: no kill/death/score change")
		check(world.players[oid].global_position.distance_to(world.level.raw_to_world(ArenaLevel.MUSEUM_CENTER)) < 25.0, "switch: respawned on the new side")
		world._srv_team_request(oid, Config.TEAM_NEGATRON)
		await get_tree().create_timer(0.3).timeout
		check(world.players.size() == 3, "switch to the same team is a no-op")
	await get_tree().create_timer(1.5).timeout  # let clients finish their checks
	await finish()

func _team_rule_checks() -> void:
	check(World.resolve_team(0, [2, 2]).team == 0, "rule: Jimmy choice honoured")
	check(World.resolve_team(1, [2, 2]).team == 1, "rule: Negatron choice honoured")
	var r := World.resolve_team(0, [5, 2])
	check(r.team == 1 and r.msg != "", "rule: full Jimmy -> placed on Negatron with message (%s)" % r.msg)
	check(World.resolve_team(1, [5, 5]).team == -1, "rule: both full -> refused")
	check(World.resolve_team(-1, [5, 4]).team == 1, "rule: auto picks smaller team")
	check(World.resolve_team(-1, [3, 3]).team == 0, "rule: auto tie -> Jimmy")
	check(World.resolve_team(-1, [5, 5]).team == -1, "rule: auto both full -> refused")

func _shoot(shooter: Player, target: Player) -> void:
	var tp := target.global_position + Vector3(0, 0.7, 0)
	shooter.fire((tp - shooter.muzzle()).normalized())

# ---------------------------------------------------------------- client
func _client() -> void:
	var ip := "127.0.0.1"
	check(await main.start_join(ip), "joined")
	world = main.world
	var manual := OS.get_cmdline_user_args().has("--manual_team")
	if manual:
		await get_tree().create_timer(2.0).timeout
		check(not world.players.has(multiplayer.get_unique_id()), "client not spawned before choosing a team")
		world.request_team(Config.TEAM_NEGATRON)
	world.hit_event.connect(func(v, _sh, d, _p, _k): if v == multiplayer.get_unique_id() and d > 0: ev.hit_on_me += 1)
	world.player_hurt.connect(func(id, hp): if id == multiplayer.get_unique_id() and hp < Config.MAX_HP: ev.hurt += 1)
	world.player_died.connect(func(id, _k): if id == multiplayer.get_unique_id(): ev.died += 1)
	world.player_respawned.connect(func(id): if id == multiplayer.get_unique_id(): ev.respawn += 1)
	world.state_changed.connect(func():
		if world.match_over: ev.over = true
		elif ev.over: ev.reset = true)
	check(await wait_for(func(): return world.players.has(multiplayer.get_unique_id()), 20.0), "own player spawned")
	var me: Player = world.players[multiplayer.get_unique_id()]
	check(me.team == Config.TEAM_NEGATRON, "client is Negatron")
	var p0 := me.global_position
	me.test_move = Vector2(0, -1)
	await get_tree().create_timer(1.0).timeout
	me.test_move = Vector2.ZERO
	check(me.global_position.distance_to(p0) > 2.0, "client moved %.1f m" % me.global_position.distance_to(p0))
	check(await wait_for(func(): return ev.died >= 1, 40.0), "client saw own death")
	check(ev.hurt >= 4, "client saw %d hp updates" % ev.hurt)
	check(ev.hit_on_me >= 5, "victim received hit_event for each hit (%d)" % ev.hit_on_me)
	check(await wait_for(func(): return ev.respawn >= 1, 10.0), "client respawned")
	await get_tree().create_timer(1.0).timeout
	var host: Player = world.players[1]
	# the bases are ~390 m apart now: put the client 4 m from the host before it retaliates
	me.global_position = host.global_position + Vector3(0, 0.3, 4)
	await get_tree().create_timer(1.0).timeout
	for i in 5:
		var tp := host.global_position + Vector3(0, 0.7, 0)
		me.fire((tp - me.muzzle()).normalized())
		await get_tree().create_timer(0.4).timeout
	check(await wait_for(func(): return world.team_score[1] >= 1, 8.0), "client sees score 0 - 1")
	check(await wait_for(func(): return ev.over, 20.0), "client saw match over")
	check(await wait_for(func(): return ev.reset, 15.0), "client saw match reset")
	check(await wait_for(func(): return me.alive, 5.0), "client alive after reset")
	await get_tree().create_timer(4.0).timeout  # stay connected until the server finished its checks
	await finish()

# ---------------------------------------------------------------- observer (relay check)
func _observer() -> void:
	check(await main.start_join("127.0.0.1"), "joined")
	world = main.world
	if OS.get_cmdline_user_args().has("--manual_team"):
		await get_tree().create_timer(3.0).timeout
		world.request_team(Config.TEAM_JIMMY)
	check(await wait_for(func(): return world.players.size() >= 3, 30.0), "sees 3 players")
	var other: Player = null
	for p in world.players.values():
		if p.team == Config.TEAM_NEGATRON:
			other = p
	check(other != null, "sees the Negatron client")
	var p0 := other.global_position
	var moved := await wait_for(func(): return other.global_position.distance_to(p0) > 2.0, 20.0)
	check(moved, "relayed client movement visible (%.1f m)" % other.global_position.distance_to(p0))
	check(await wait_for(func(): return world.team_score[0] >= 1, 30.0), "sees score update")
	check(await wait_for(func(): return world.match_over, 40.0), "sees match over")
	await get_tree().create_timer(10.0).timeout
	await finish()
