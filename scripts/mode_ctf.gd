class_name ModeCtf
extends GameMode
## Capture the Goddard. Each team owns a flag at its base: Jimmy's is Goddard (Candy Bar side), Negatron's is the propeller
## goof-bot (museum side). Touch the enemy flag to carry it, touch your own dropped flag to return it, bring the enemy flag
## to your own base while your own flag is home to capture. A carrier who dies drops the flag where he fell.
enum { HOME, CARRIED, DROPPED }
const FLAG_NAMES := ["Goddard", "Goof-Bot"]
var homes := [Vector3.ZERO, Vector3.ZERO]
## flag[t] is team t's flag: {st, pos, carrier, since}
var flag := []
var last_pos := {}   # carrier id -> last known position (drop point)
var clock := 0.0
var winner_team := -1

func _init() -> void:
	id = &"ctf"
	display_name = "Capture the Goddard"
	desc = "Steal the enemy flag, bring it to your base while yours is home. First to %d captures." % Balance.CTF.capture_limit
	_reset_flags()

func _reset_flags() -> void:
	flag = []
	for t in 2:
		flag.append({"st": HOME, "pos": homes[t], "carrier": 0, "since": 0.0})

func setup_level(level: ArenaLevel) -> void:
	set_homes([level.flag_home(0), level.flag_home(1)])

func set_homes(h: Array) -> void:
	homes = h
	_reset_flags()

func reset() -> void:
	super.reset()
	winner_team = -1
	clock = 0.0
	last_pos.clear()
	_reset_flags()

func carrying(pid: int) -> int:
	## team index of the flag `pid` carries, -1 = none
	for t in 2:
		if flag[t].st == CARRIED and flag[t].carrier == pid:
			return t
	return -1

func _drop(t: int, at: Vector3) -> String:
	flag[t].st = DROPPED
	flag[t].pos = at
	flag[t].carrier = 0
	flag[t].since = clock
	return "%s flag dropped" % FLAG_NAMES[t]

func _return(t: int) -> void:
	flag[t].st = HOME
	flag[t].pos = homes[t]
	flag[t].carrier = 0

func on_death(pid: int, pos: Vector3) -> Array:
	var t := carrying(pid)
	if t >= 0:
		return [_drop(t, pos)]
	return []

func _near(a: Vector3, b: Vector3, r: float) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() <= r and absf(a.y - b.y) < 4.0

func tick(dt: float, ps: Array) -> Array:
	var msgs := []
	clock += dt
	var by_id := {}
	for p in ps:
		by_id[p.id] = p
	var rad: float = Balance.CTF.pickup_radius
	# a carrier that left, died unseen or changed team drops at its last known position
	for t in 2:
		if flag[t].st == CARRIED:
			var c: Variant = by_id.get(flag[t].carrier)
			if c == null or not c.alive or c.team == t:
				msgs.append(_drop(t, last_pos.get(flag[t].carrier, flag[t].pos)))
			else:
				last_pos[flag[t].carrier] = c.pos
				flag[t].pos = c.pos
	# dropped flags time out back home
	for t in 2:
		if flag[t].st == DROPPED and clock - flag[t].since >= Balance.CTF.drop_return:
			_return(t)
			msgs.append("%s flag returned" % FLAG_NAMES[t])
	# touches
	for p in ps:
		if not p.alive:
			continue
		var team: int = p.team
		var enemy := 1 - team
		# own flag: return it when dropped
		if flag[team].st == DROPPED and _near(p.pos, flag[team].pos, rad):
			_return(team)
			msgs.append("%s flag returned" % FLAG_NAMES[team])
		# enemy flag: pick up
		if flag[enemy].st != CARRIED and _near(p.pos, flag[enemy].pos, rad):
			flag[enemy].st = CARRIED
			flag[enemy].carrier = p.id
			last_pos[p.id] = p.pos
			msgs.append("%s flag taken" % FLAG_NAMES[enemy])
		# capture: carrying the enemy flag, at own base, own flag home
		if carrying(p.id) == enemy and flag[team].st == HOME and _near(p.pos, homes[team], rad):
			scores[team] += 1
			_return(enemy)
			msgs.append("%s captured the %s flag!" % [Config.TEAM_NAMES[team], FLAG_NAMES[enemy]])
			if scores[team] >= Balance.CTF.capture_limit:
				winner_team = team
	return msgs

func result() -> Dictionary:
	if winner_team >= 0:
		return {"team": winner_team, "player": 0, "text": "%s TEAM WINS!" % Config.TEAM_NAMES[winner_team]}
	return {}

func state() -> Dictionary:
	return {"f": [[flag[0].st, flag[0].pos, flag[0].carrier], [flag[1].st, flag[1].pos, flag[1].carrier]], "h": homes}

func apply_state(d: Dictionary) -> void:
	var f: Array = d.get("f", [])
	homes = d.get("h", homes)
	if f.size() == 2:
		for t in 2:
			flag[t].st = f[t][0]; flag[t].pos = f[t][1]; flag[t].carrier = f[t][2]

func score_line() -> String:
	return "JIMMY %d  -  %d NEGATRON   (captures to %d)" % [scores[0], scores[1], Balance.CTF.capture_limit]

func _status(t: int) -> String:
	match flag[t].st:
		CARRIED: return "taken"
		DROPPED: return "dropped"
	return "home"

func objective_text(pid: int, team: int) -> String:
	if team < 0:
		return ""
	var mine := carrying(pid)
	if mine >= 0:
		return "You carry the %s flag: run to your base (your flag must be home)" % FLAG_NAMES[mine]
	return "Your flag (%s): %s   Enemy flag (%s): %s" % [FLAG_NAMES[team], _status(team), FLAG_NAMES[1 - team], _status(1 - team)]

func board_extra(pid: int) -> String:
	var t := carrying(pid)
	return ("  [carries %s]" % FLAG_NAMES[t]) if t >= 0 else ""

## Bot roles: 2 of 3 attack (every bot whose |id| % 3 != 0), the rest defend.
func bot_goal(pid: int, team: int, pos: Vector3) -> Variant:
	var enemy := 1 - team
	if carrying(pid) == enemy:
		return homes[team]
	var defender := absi(pid) % 3 == 0
	if flag[team].st == DROPPED and pos.distance_to(flag[team].pos) < 70.0:
		return flag[team].pos          # return our flag
	if defender:
		if flag[team].st == CARRIED:
			return flag[team].pos      # chase the thief
		return homes[team]
	if flag[enemy].st == CARRIED and flag[enemy].carrier != pid:
		return flag[enemy].pos         # escort our carrier / go with him
	return flag[enemy].pos

func bot_rush(pid: int) -> bool:
	return carrying(pid) >= 0
