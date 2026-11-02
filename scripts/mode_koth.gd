class_name ModeKoth
extends GameMode
## King of the Candy Bar: one capture zone. While exactly one team has living players in it, that team earns points per second;
## both teams inside = contested, nobody scores. First to Balance.KOTH.limit wins.
var center := Vector3.ZERO
var holder := -1        # -1 nobody in the zone, 0/1 holding, 2 contested
var acc := [0.0, 0.0]
var winner_team := -1

func _init() -> void:
	id = &"koth"
	display_name = "King of the Candy Bar"
	desc = "Hold the zone alone to score. Both teams inside = contested. First to %d points." % Balance.KOTH.limit

## HOOK: an interior map can set LAYOUTS[..].hill (raw x, z) later; until then the middle of the street route is used.
func setup_level(level: ArenaLevel) -> void:
	center = level.hill_center()

func reset() -> void:
	super.reset()
	acc = [0.0, 0.0]
	holder = -1
	winner_team = -1

## who is in the zone: -1 nobody, 0/1 one team, 2 both
func occupancy(ps: Array) -> int:
	var seen := [false, false]
	for p in ps:
		if p.alive and Vector2(p.pos.x - center.x, p.pos.z - center.z).length() <= Balance.KOTH.radius and absf(p.pos.y - center.y) < 5.0:
			seen[p.team] = true
	if seen[0] and seen[1]:
		return 2
	if seen[0]:
		return 0
	if seen[1]:
		return 1
	return -1

func tick(dt: float, ps: Array) -> Array:
	holder = occupancy(ps)
	if holder == 0 or holder == 1:
		acc[holder] += dt * Balance.KOTH.pps
		scores[holder] = int(acc[holder])
		if scores[holder] >= Balance.KOTH.limit:
			winner_team = holder
	return []

func result() -> Dictionary:
	if winner_team >= 0:
		return {"team": winner_team, "player": 0, "text": "%s TEAM WINS!" % Config.TEAM_NAMES[winner_team]}
	return {}

func state() -> Dictionary:
	return {"c": center, "hd": holder}

func apply_state(d: Dictionary) -> void:
	center = d.get("c", center)
	holder = d.get("hd", holder)

func score_line() -> String:
	return "JIMMY %d  -  %d NEGATRON   (first to %d)" % [scores[0], scores[1], Balance.KOTH.limit]

func objective_text(_pid: int, _team: int) -> String:
	match holder:
		0, 1: return "%s hold the zone" % Config.TEAM_NAMES[holder]
		2: return "Zone CONTESTED"
	return "Zone is free: go capture it"

func bot_goal(_pid: int, _team: int, _pos: Vector3) -> Variant:
	return center
