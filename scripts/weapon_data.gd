class_name WeaponData
extends Resource
## Data-driven weapon definition. Loadouts (later) = picking a different id from the registry.
@export var id: StringName = &"bubble_gun"
@export var display_name := "Bubble Gun"
@export var damage := 20
@export var projectile_speed := 30.0   # m/s
@export var projectile_radius := 0.15  # m
@export var lifetime := 2.5            # s
@export var fire_interval := 0.3       # s
@export var gravity := 0.0             # m/s^2 applied to projectile

static var _registry := {}

static func bubble_gun() -> WeaponData:
	return WeaponData.new()

static func get_weapon(wid: StringName) -> WeaponData:
	if _registry.is_empty():
		var bg := bubble_gun()
		_registry[bg.id] = bg
	return _registry.get(wid, _registry[&"bubble_gun"])
