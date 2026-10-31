class_name Loadout
extends RefCounted
## Loadout = Dictionary {primary, gadget, movement, ultimate} of StringName ids. Helpers for class presets + validation.
static func from_class(cid: StringName) -> Dictionary:
	var c: Dictionary = Balance.CLASSES.get(cid, Balance.CLASSES[Balance.DEFAULT_CLASS])
	var out := {}
	for s in Balance.SLOTS:
		out[s] = c[s]
	return out

static func default_loadout() -> Dictionary:
	return from_class(Balance.DEFAULT_CLASS)

## Returns a valid loadout (unknown/hidden ids replaced from the default class).
static func sanitize(lo: Dictionary) -> Dictionary:
	var out := default_loadout()
	var tables := {&"primary": WeaponData.selectable_ids(), &"gadget": GadgetData.all_ids(), &"movement": MovementData.all_ids(), &"ultimate": UltimateData.all_ids()}
	for s in Balance.SLOTS:
		var v := StringName(str(lo.get(s, out[s])))
		if tables[s].has(v):
			out[s] = v
	return out

static func max_hp(lo: Dictionary) -> int:
	return Config.MAX_HP + int(MovementData.get_movement(lo.movement).f("hp_bonus"))

static func to_wire(lo: Dictionary) -> Dictionary:
	var out := {}
	for s in Balance.SLOTS:
		out[str(s)] = str(lo[s])
	return out
