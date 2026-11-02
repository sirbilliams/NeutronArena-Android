extends Node
## Game mode rules (pure logic, no assets): godot --headless --path . res://tests/modes_test.tscn
var fails := 0
func check(c: bool, m: String) -> void:
	print("  [", "ok" if c else "FAIL", "] ", m)
	if not c: fails += 1

func pl(id: int, team: int, pos: Vector3, alive := true) -> Dictionary:
	return {"id": id, "team": team, "pos": pos, "alive": alive}

func _ready() -> void:
	_gun()
	_tdm()
	_ctf()
	_koth()
	_vote()
	_registry()
	print("MODES TEST ", "PASS" if fails == 0 else "FAIL")
	get_tree().quit(0 if fails == 0 else 1)

func _gun() -> void:
	var g := ModeGunGame.new()
	var lad := ModeGunGame.ladder()
	check(lad.size() >= 3 and lad[0] == &"water_gun" and lad[lad.size() - 1] == &"mega_burp", "gun game ladder weakest -> strongest (%d steps)" % lad.size())
	for w in lad:
		check(WeaponData.selectable_ids().has(w), "ladder weapon %s is selectable" % w)
	check(not g.gadgets_allowed(), "gun game: gadgets off")
	check(g.loadout_for(1, Loadout.default_loadout()).primary == lad[0], "level 0 forces the first weapon")
	g.on_kill(1, 0, -1, 1)
	check(g.level_of(1) == 1 and g.weapon_of(1) == lad[1] and g.take_dirty().has(1), "kill: killer up one step, loadout pushed")
	check(g.level_of(-1) == 0, "victim at level 0 stays at 0")
	g.on_kill(-1, 1, 1, 0)
	check(g.level_of(1) == 0 and g.level_of(-1) == 1, "dying to an enemy: down one step; his killer up")
	g.on_kill(1, 0, 1, 0)
	check(g.level_of(1) == 0, "suicide / self kill changes nothing")
	g.on_kill(2, 0, 3, 0)
	check(g.level_of(2) == 0, "teamkill changes nothing")
	for i in lad.size() - 1:
		g.on_kill(5, 0, -9, 1)
	check(g.level_of(5) == lad.size() - 1 and g.result().is_empty(), "last step reached, not won yet")
	g.on_kill(5, 0, -9, 1)
	check(g.result().get("player", 0) == 5, "kill with the last weapon wins")
	g.reset()
	check(g.result().is_empty() and g.level_of(5) == 0, "reset clears ladder")

func _tdm() -> void:
	var t := ModeTdm.new()
	t.on_kill(1, 0, -1, 1)
	check(t.scores == [1, 0] and t.result().is_empty(), "tdm: kill scores for killer team")
	t.scores[1] = Config.WIN_SCORE
	check(t.result().team == 1, "tdm: WIN_SCORE wins")

func _ctf() -> void:
	var c := ModeCtf.new()
	var hj := Vector3(0, 0, 0)
	var hn := Vector3(100, 0, 0)
	c.set_homes([hj, hn])
	var J := 0
	var N := 1
	# Jimmy player 1 walks to the Negatron flag
	c.tick(0.1, [pl(1, J, Vector3(50, 0, 0))])
	check(c.flag[N].st == ModeCtf.HOME, "far from the flag: nothing")
	c.tick(0.1, [pl(1, J, hn + Vector3(1, 0, 0))])
	check(c.flag[N].st == ModeCtf.CARRIED and c.flag[N].carrier == 1 and c.carrying(1) == N, "enemy touch: pickup")
	c.tick(0.1, [pl(1, J, Vector3(70, 0, 0))])
	check(c.flag[N].pos.is_equal_approx(Vector3(70, 0, 0)), "flag follows the carrier")
	# carrier dies -> drops
	c.on_death(1, Vector3(60, 0, 0))
	check(c.flag[N].st == ModeCtf.DROPPED and c.flag[N].pos.is_equal_approx(Vector3(60, 0, 0)) and c.carrying(1) == -1, "carrier death: flag dropped at his feet")
	# dropped flag: own team (Negatron) touches -> returns; enemy touches -> picks up
	c.tick(0.1, [pl(2, N, Vector3(60.5, 0, 0))])
	check(c.flag[N].st == ModeCtf.HOME and c.flag[N].pos.is_equal_approx(hn), "own team touch: flag returns home")
	# pickup again, then capture is blocked while own flag is away
	c.tick(0.1, [pl(1, J, hn)])
	check(c.flag[N].st == ModeCtf.CARRIED, "picked up again")
	c.tick(0.1, [pl(1, J, hn), pl(2, N, hj)])
	check(c.flag[J].st == ModeCtf.CARRIED and c.flag[J].carrier == 2, "Negatron takes Goddard")
	c.tick(0.1, [pl(1, J, hj), pl(2, N, Vector3(50, 0, 40))])
	check(c.scores == [0, 0], "no capture while own flag is not home")
	# Negatron carrier is killed, Goddard returns by Jimmy touch, then Jimmy captures
	c.on_death(2, Vector3(0, 0, 3))
	c.tick(0.1, [pl(1, J, Vector3(0, 0, 3))])
	check(c.flag[J].st == ModeCtf.HOME, "Goddard returned by Jimmy")
	var m := c.tick(0.1, [pl(1, J, hj)])
	check(c.scores == [1, 0] and c.flag[N].st == ModeCtf.HOME and c.carrying(1) == -1 and m.size() > 0, "capture: Jimmy +1, goof-bot flag back home")
	# dead players cannot pick up; carrier leaving the match drops
	c.tick(0.1, [pl(1, J, hn, false)])
	check(c.flag[N].st == ModeCtf.HOME, "dead player cannot pick up")
	c.tick(0.1, [pl(1, J, hn)])
	c.tick(0.1, [])
	check(c.flag[N].st == ModeCtf.DROPPED, "carrier disconnects: flag dropped")
	c.tick(Balance.CTF.drop_return + 0.1, [])
	check(c.flag[N].st == ModeCtf.HOME, "dropped flag returns by itself after the timeout")
	# win at the capture limit
	c.scores[J] = Balance.CTF.capture_limit - 1
	c.tick(0.1, [pl(1, J, hn)])
	c.tick(0.1, [pl(1, J, hj)])
	check(c.result().get("team", -1) == J, "capture limit wins the round")
	# bots
	var c2 := ModeCtf.new()
	c2.set_homes([hj, hn])
	check(c2.bot_goal(1, J, Vector3.ZERO) == hn, "attacker bot goes for the enemy flag")
	check(c2.bot_goal(3, J, Vector3.ZERO) == hj, "defender bot guards the own flag")
	c2.tick(0.1, [pl(1, J, hn)])
	check(c2.bot_goal(1, J, hn) == hj and c2.bot_rush(1), "carrier bot runs home and ignores enemies")

func _koth() -> void:
	var k := ModeKoth.new()
	k.center = Vector3(10, 0, 10)
	var inz := Vector3(12, 0, 10)
	var out := Vector3(60, 0, 10)
	k.tick(1.0, [pl(1, 0, out)])
	check(k.holder == -1 and k.scores == [0, 0], "nobody in the zone: no points")
	k.tick(1.0, [pl(1, 0, inz), pl(2, 1, out)])
	check(k.holder == 0 and k.scores[0] == int(Balance.KOTH.pps) and k.scores[1] == 0, "one team holds: it scores %.1f/s" % Balance.KOTH.pps)
	var before: Array = k.scores.duplicate()
	k.tick(1.0, [pl(1, 0, inz), pl(2, 1, inz)])
	check(k.holder == 2 and k.scores == before, "both teams inside: contested, no points")
	k.tick(1.0, [pl(1, 0, inz, false), pl(2, 1, inz)])
	check(k.holder == 1 and k.scores[1] > 0, "dead player does not contest")
	k.tick(1000.0, [pl(1, 0, inz)])
	check(k.result().get("team", -1) == 0, "limit wins")
	check(k.bot_goal(1, 0, Vector3.ZERO) == k.center, "bots go to the zone")

func _vote() -> void:
	var v := MapVote.new(["tdm", "gun_game", "ctf", "koth"], ["museum", "compact"])
	v.cast(1, 2, 1)
	v.cast(2, 2, 0)
	v.cast(3, 0, 1)
	check(v.mode_counts() == [1, 0, 2, 0] and v.map_counts() == [1, 2], "counts")
	var r := v.result()
	check(r.mode == "ctf" and r.map == "compact", "majority wins (%s / %s)" % [r.mode, r.map])
	v.cast(3, 2, -1)
	check(v.mode_counts() == [0, 0, 3, 0] and v.map_counts() == [1, 2], "changing a vote replaces it; -1 leaves a ballot alone")
	v.cast(1, 99, 99)
	check(v.mode_votes.size() == 3, "out-of-range ballot ignored")
	v.forget(3)
	check(v.mode_votes.size() == 2, "forget removes a voter")
	# ties and empty = random among leaders only
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 60:
		seen[MapVote.tally({1: 0, 2: 1}, 4, rng)] = true
	check(seen.keys().size() == 2 and seen.has(0) and seen.has(1), "tie between 2: both can win, nothing else")
	seen.clear()
	for i in 80:
		seen[MapVote.tally({}, 4, rng)] = true
	check(seen.keys().size() == 4, "no votes: random over all options")
	check(MapVote.tally({}, 0) == -1, "no options: -1")

func _registry() -> void:
	for m in Modes.IDS:
		var gm := Modes.create(m)
		check(gm.id == m and gm.display_name != "", "registry: %s" % m)
	check(Modes.create(&"bogus").id == &"tdm", "unknown id falls back to tdm")
	var lv := ArenaLevel.new()
	lv.layout_name = "museum"
	lv._build_zones()
	var j := lv.flag_home(0)
	var n := lv.flag_home(1)
	check(j.distance_to(n) > 100.0, "flag stands far apart (%.0f m)" % j.distance_to(n))
	lv.layout_name = "compact"
	lv._build_zones()
	check(lv.flag_home(0).distance_to(lv.flag_home(1)) > 30.0, "compact map flag stands apart")
	check(lv.hill_center().length() > 0.0, "hill centre exists")
