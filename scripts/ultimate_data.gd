class_name UltimateData
extends Resource
## Data-driven ultimate definition; numbers come from Balance.ULTIMATES.
@export var id: StringName
@export var display_name := ""
@export var desc := ""
@export var p := {}   ## raw parameter dictionary (cooldown, duration, ...)

static var _registry := {}

static func get_ultimate(gid: StringName) -> UltimateData:
	if _registry.is_empty():
		for k in Balance.ULTIMATES:
			var d: Dictionary = Balance.ULTIMATES[k]
			var r := UltimateData.new()
			r.id = k; r.display_name = d.name; r.desc = d.desc; r.p = d
			_registry[k] = r
	return _registry.get(gid, _registry[Balance.ULTIMATES.keys()[0]])

static func all_ids() -> Array:
	return Balance.ULTIMATES.keys()

func f(key: String, dflt := 0.0) -> float:
	return float(p.get(key, dflt))

## Team-specific display name (Jimmy: Goddard Scooter, Negatron: Negatron Scooter)
func name_for(team: int) -> String:
	return str(p.get("name_negatron", display_name)) if team == Config.TEAM_NEGATRON else display_name
