class_name MovementData
extends Resource
## Data-driven movement definition; numbers come from Balance.MOVEMENTS.
@export var id: StringName
@export var display_name := ""
@export var desc := ""
@export var p := {}   ## raw parameter dictionary (cooldown, duration, ...)

static var _registry := {}

static func get_movement(gid: StringName) -> MovementData:
	if _registry.is_empty():
		for k in Balance.MOVEMENTS:
			var d: Dictionary = Balance.MOVEMENTS[k]
			var r := MovementData.new()
			r.id = k; r.display_name = d.name; r.desc = d.desc; r.p = d
			_registry[k] = r
	return _registry.get(gid, _registry[Balance.MOVEMENTS.keys()[0]])

static func all_ids() -> Array:
	return Balance.MOVEMENTS.keys()

func f(key: String, dflt := 0.0) -> float:
	return float(p.get(key, dflt))
