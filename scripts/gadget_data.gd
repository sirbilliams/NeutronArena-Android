class_name GadgetData
extends Resource
## Data-driven gadget definition; numbers come from Balance.GADGETS.
@export var id: StringName
@export var display_name := ""
@export var desc := ""
@export var p := {}   ## raw parameter dictionary (cooldown, duration, ...)

static var _registry := {}

static func get_gadget(gid: StringName) -> GadgetData:
	if _registry.is_empty():
		for k in Balance.GADGETS:
			var d: Dictionary = Balance.GADGETS[k]
			var r := GadgetData.new()
			r.id = k; r.display_name = d.name; r.desc = d.desc; r.p = d
			_registry[k] = r
	return _registry.get(gid, _registry[Balance.GADGETS.keys()[0]])

static func all_ids() -> Array:
	return Balance.GADGETS.keys()

func f(key: String, dflt := 0.0) -> float:
	return float(p.get(key, dflt))
