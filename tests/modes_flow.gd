extends Node
## Single-process integration of the mode framework on a real host world with bots (tests/run_modes_test.sh, part 2).
var main: Node
var world: World
var fails := 0
func check(c: bool, m: String) -> void:
	print("  [", "ok" if c else "FAIL", "] ", m)
	if not c: fails += 1

func wait_for(cb: Callable, timeout := 20.0) -> bool:
	var t := 0.0
	while t < timeout:
		if cb.call():
			return true
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	return false

func _ready() -> void:
	check(await main.start_host(), "host started")
	world = main.world
	check(await wait_for(func(): return world.players.size() >= 10, 40.0), "10 players")
	world.bot_mgr.set_physics_process(false)   # bots stand still: the test places everyone itself
	var J := Config.TEAM_JIMMY
	var N := Config.TEAM_NEGATRON
	var jim: int = 1
	var neg: int = world.srv_bot_ids(N)[0]
	# ---- gun game
	world._srv_reset_match(&"gun_game", "")
	await get_tree().create_timer(0.5).timeout
	check(world.mode.id == &"gun_game" and world.info[jim].loadout.primary == Balance.GUN_LADDER[0], "gun game: everyone starts on the first weapon")
	world.info[neg].hp = 10
	world.srv_hit(neg, jim, 50)
	check(world.mode.level_of(jim) == 1 and world.info[jim].loadout.primary == Balance.GUN_LADDER[1] and world.players[jim].weapon.id == Balance.GUN_LADDER[1], "gun game: kill upgrades the killer's server + player weapon")
	world._srv_gadget(jim, Vector3.ZERO, Vector3.FORWARD)
	check(world.traps.is_empty(), "gun game: gadget refused")
	await wait_for(func(): return world.info[neg].alive, 6.0)
	world.info[jim].hp = 10
	world.srv_hit(jim, neg, 50)
	check(world.mode.level_of(jim) == 0 and world.info[jim].loadout.primary == Balance.GUN_LADDER[0], "gun game: dying to an enemy downgrades")
	await wait_for(func(): return world.info[jim].alive, 6.0)
	world.mode.level[jim] = Balance.GUN_LADDER.size() - 1
	world.info[neg].hp = 10
	world.srv_hit(neg, jim, 50)
	check(world.match_over and world.winner_text.contains("WINS"), "gun game: kill with the last weapon ends the round (%s)" % world.winner_text)
	# ---- ctf on the compact map
	world._srv_reset_match(&"ctf", "compact")
	await get_tree().create_timer(0.5).timeout
	check(world.mode.id == &"ctf" and world.level.layout_name == "compact" and not world.match_over, "ctf on compact map, new round")
	var fj: Vector3 = world.mode.homes[J]
	var fn: Vector3 = world.mode.homes[N]
	world.players[jim].global_position = fn
	world._srv_mode_tick(0.1)
	check(world.mode.flag[N].st == ModeCtf.CARRIED and world.mode.flag[N].carrier == jim, "ctf: Jimmy picks up the goof-bot flag")
	world.info[jim].hp = 1
	world.srv_hit(jim, neg, 50)
	check(world.mode.flag[N].st == ModeCtf.DROPPED, "ctf: carrier killed, flag dropped")
	await wait_for(func(): return world.info[jim].alive, 6.0)
	world.players[jim].global_position = fn
	world._srv_mode_tick(0.1)
	world.players[jim].global_position = fj
	world._srv_mode_tick(0.1)
	check(world.team_score[J] == 1, "ctf: capture scores for Jimmy (%s)" % str(world.team_score))
	# ---- koth
	world._srv_reset_match(&"koth", "")
	await get_tree().create_timer(0.5).timeout
	check(world.mode.id == &"koth" and world.level.layout_name == "compact", "koth round, map kept")
	world.players[jim].global_position = world.mode.center
	world._srv_mode_tick(1.0)
	check(world.team_score[J] >= 1, "koth: holding scores (%s)" % str(world.team_score))
	# ---- vote
	world.match_over = true
	Config.vote_enabled = true
	Config.test_mode = false
	world._srv_round_end()
	Config.test_mode = true
	check(world.voting and world.vote != null, "vote opened")
	world.request_vote(world.vote.mode_options.find("gun_game"), world.vote.map_options.find("museum"))
	check(world.vote.mode_counts()[world.vote.mode_options.find("gun_game")] == 1, "host vote counted")
	check(await wait_for(func(): return not world.voting and world.mode.id == &"gun_game" and world.level.layout_name == "museum", 6.0), "all humans voted: winner applied (gun game / museum)")
	check(not world.match_over, "next round running")
	# skip
	world.match_over = true
	Config.test_mode = false
	world._srv_round_end()
	Config.test_mode = true
	world.request_vote_skip()
	check(not world.voting and not world.match_over, "skip ends the vote and starts the round")
	print("MODES FLOW ", "PASS" if fails == 0 else "FAIL")
	get_tree().quit(0 if fails == 0 else 1)
