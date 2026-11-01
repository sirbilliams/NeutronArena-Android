extends Node
## Headless bot test (tests/run_bot_test.sh). Roles: server (host + 9 bots), client (joins later, replaces a bot).
var main: Node
var role := ""
var world: World
var fails: Array[String] = []

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
	if role == "server":
		_server()
	else:
		_client()

func _bots() -> Array:
	return world.players.keys().filter(func(i): return i < 0)

func _bot_kills() -> int:
	var n := 0
	for i in world.kills:
		if i < 0:
			n += world.kills[i]
	return n

func _server() -> void:
	check(await main.start_host(), "host started")
	world = main.world
	check(await wait_for(func(): return world.players.size() >= 10, 60.0), "10 players present (1 human + bots): %d" % world.players.size())
	var teams := [0, 0]
	for p in world.players.values(): teams[p.team] += 1
	check(teams == [5, 5], "teams 5v5 %s" % str(teams))
	check(_bots().size() == 9, "9 bots (%d)" % _bots().size())
	# LAN beacon: a listener in this process must see the host's broadcast
	var lb := LanBeacon.new()
	add_child(lb)
	check(lb.start_listen(), "beacon listener bound")
	var got := await wait_for(func(): return not lb.games().is_empty(), 5.0)
	check(got, "beacon found the game")
	if got:
		var g: Dictionary = lb.games()[0]
		check(g.players == 1 and g.bots == 9 and g.port == main.port, "beacon content players=%d bots=%d port=%d" % [g.players, g.bots, g.port])
	lb.queue_free()
	# movement: path length per bot
	var start := {}
	var path := {}
	var last := {}
	for id in _bots():
		last[id] = world.players[id].global_position
		start[id] = last[id]
		path[id] = 0.0
	var t0 := Time.get_ticks_msec() / 1000.0
	var replaced := false
	var thirty_done := false
	var ms_samples := []
	while Time.get_ticks_msec() / 1000.0 - t0 < 100.0:
		await get_tree().create_timer(0.5).timeout
		var el := Time.get_ticks_msec() / 1000.0 - t0
		for id in _bots():
			var pos: Vector3 = world.players[id].global_position
			if last.has(id) and world.players[id].alive:
				var d := Vector2(pos.x - last[id].x, pos.z - last[id].z).length()
				if d < 5.0:
					path[id] = path.get(id, 0.0) + d
			last[id] = pos
		if main.world.bot_mgr:
			ms_samples.append(main.world.bot_mgr.take_avg_ms())
		if not thirty_done and el >= 30.0:
			thirty_done = true
			var movers := 0
			var best := 0.0
			for id in path:
				best = maxf(best, path[id])
				if path[id] > 20.0: movers += 1
			check(movers >= 7, "bots moved >20 m in 30 s: %d/9 (max path %.0f m)" % [movers, best])
		if not replaced and world.info.keys().any(func(i): return i > 1):
			replaced = true
			await get_tree().create_timer(1.0).timeout
			var humans := world.info.keys().filter(func(i): return i > 0).size()
			check(world.players.size() == 10 and _bots().size() == 8 and humans == 2, "client replaced a bot: players=%d bots=%d humans=%d" % [world.players.size(), _bots().size(), humans])
		if replaced and thirty_done and _bot_kills() > 0 and el >= 40.0:
			break
	check(replaced, "a client joined")
	check(_bot_kills() > 0, "bot kills=%d at %.0f s" % [_bot_kills(), Time.get_ticks_msec() / 1000.0 - t0])
	var avg := 0.0
	var peak := 0.0
	for m in ms_samples:
		avg += m
		peak = maxf(peak, m)
	avg /= maxf(ms_samples.size(), 1)
	print("  BOT CPU: mean %.3f ms/frame (peak 0.5s-mean %.3f ms), peak single frame %.2f ms, 9 bots" % [avg, peak, main.world.bot_mgr.stat_peak_us / 1000.0])
	print("  scoreboard score=%s kills=%s" % [str(world.team_score), str(world.kills)])
	await finish()

func _client() -> void:
	check(await main.start_join("127.0.0.1"), "client started")
	world = main.world
	check(await wait_for(func(): return world.players.has(main.multiplayer.get_unique_id()), 30.0), "client player spawned")
	check(await wait_for(func(): return world.players.size() >= 10, 10.0), "client sees 10 players (%d)" % world.players.size())
	var b := world.players.keys().filter(func(i): return i < 0)
	check(b.size() == 8, "client sees 8 bots (%d)" % b.size())
	var p0 := {}
	for id in b: p0[id] = world.players[id].global_position
	await get_tree().create_timer(12.0).timeout
	var moved := 0
	for id in b:
		if world.players.has(id) and world.players[id].global_position.distance_to(p0[id]) > 5.0: moved += 1
	check(moved >= 5, "bots replicate movement on the client: %d/8 moved >5 m" % moved)
	await finish()
