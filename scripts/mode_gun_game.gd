class_name ModeGunGame
extends GameMode
## Gun Game: everyone climbs Balance.GUN_LADDER (weakest weapon first). A kill = one step up, dying to an enemy = one step
## down (never below the first), a kill with the last weapon wins. No gadgets / ultimates.
var level := {}     # peer id -> ladder index (0 = first weapon)
var winner := 0
var winner_team := -1

func _init() -> void:
	id = &"gun_game"
	display_name = "Gun Game"
	desc = "Every kill gives you the next weapon. Die and drop one. Finish the ladder to win."

static func ladder() -> Array:
	return Balance.GUN_LADDER

func level_of(pid: int) -> int:
	return level.get(pid, 0)

func weapon_of(pid: int) -> StringName:
	return ladder()[mini(level_of(pid), ladder().size() - 1)]

func gadgets_allowed() -> bool:
	return false

func loadout_for(pid: int, lo: Dictionary) -> Dictionary:
	var out := lo.duplicate()
	out["primary"] = weapon_of(pid)
	return out

func on_kill(killer: int, killer_team: int, victim: int, victim_team: int) -> Array:
	var msgs := []
	if killer == 0 or killer == victim or killer_team == victim_team:
		return msgs
	if level_of(victim) > 0:
		level[victim] = level_of(victim) - 1
		dirty_loadouts.append(victim)
	level[killer] = level_of(killer) + 1
	if level[killer] >= ladder().size():
		level[killer] = ladder().size() - 1
		winner = killer
		winner_team = killer_team
	else:
		dirty_loadouts.append(killer)
	return msgs

func result() -> Dictionary:
	if winner != 0:
		return {"team": winner_team, "player": winner, "text": "%s WINS GUN GAME!" % ("BOT %d" % -winner if winner < 0 else "PLAYER %d" % winner)}
	return {}

func reset() -> void:
	super.reset()
	level.clear()
	winner = 0
	winner_team = -1

func state() -> Dictionary:
	return {"lv": level.duplicate()}

func apply_state(d: Dictionary) -> void:
	level = d.get("lv", {})

## [leader id, leader level]
func leader() -> Array:
	var best := 0
	var bl := -1
	for pid in level:
		if level[pid] > bl:
			bl = level[pid]
			best = pid
	return [best, maxi(bl, 0)]

func score_line() -> String:
	var l := leader()
	return "GUN GAME   leader: %s  %d/%d" % [("Bot %d" % -l[0]) if l[0] < 0 else ("Player %d" % l[0]) if l[0] > 0 else "-", l[1] + 1, ladder().size()]

func objective_text(pid: int, _team: int) -> String:
	return "Weapon %d/%d: %s" % [level_of(pid) + 1, ladder().size(), Balance.WEAPONS[weapon_of(pid)].name]

func board_extra(pid: int) -> String:
	return "  lvl %d/%d" % [level_of(pid) + 1, ladder().size()]
