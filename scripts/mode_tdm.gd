class_name ModeTdm
extends GameMode
## Team Deathmatch: every kill scores for the killer's team, first to Config.WIN_SCORE wins.
func _init() -> void:
	id = &"tdm"
	display_name = "Team Deathmatch"
	desc = "Kill the other team. First to %d wins." % Config.WIN_SCORE

func on_kill(_killer: int, killer_team: int, _victim: int, _victim_team: int) -> Array:
	if killer_team >= 0:
		scores[killer_team] += 1
	return []

func result() -> Dictionary:
	for t in 2:
		if scores[t] >= Config.WIN_SCORE:
			return {"team": t, "player": 0, "text": "%s TEAM WINS!" % Config.TEAM_NAMES[t]}
	return {}

func score_line() -> String:
	return "JIMMY %d  -  %d NEGATRON   (first to %d)" % [scores[0], scores[1], Config.WIN_SCORE]
