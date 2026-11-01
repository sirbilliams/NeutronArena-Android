class_name WeaponData
extends Resource
## Data-driven weapon definition; numbers come from Balance.WEAPONS.
@export var id: StringName = &"bubble_gun"
@export var display_name := "Bubble Gun"
@export var desc := ""
@export var damage := 20
@export var projectile_speed := 30.0   # m/s
@export var projectile_radius := 0.15  # m
@export var lifetime := 2.5            # s
@export var fire_interval := 0.3       # s
@export var gravity := 0.0             # m/s^2 applied to projectile
@export var pellets := 1
@export var spread := 0.0              # lateral random offset per unit direction
@export var slow_time := 0.0
@export var slow_factor := 1.0
@export var charge_time := 0.0         # >0: hold to charge
@export var min_charge := 0.0          # damage fraction at zero charge
@export var hidden := false            # not selectable (ultimate weapons)

static var _registry := {}

static func bubble_gun() -> WeaponData:
	return get_weapon(&"bubble_gun")

static func get_weapon(wid: StringName) -> WeaponData:
	if _registry.is_empty():
		for k in Balance.WEAPONS:
			var d: Dictionary = Balance.WEAPONS[k]
			var w := WeaponData.new()
			w.id = k; w.display_name = d.name; w.desc = d.desc
			w.damage = d.damage; w.projectile_speed = d.speed; w.projectile_radius = d.radius
			w.lifetime = d.lifetime; w.fire_interval = d.interval; w.gravity = d.get("gravity", 0.0)
			w.pellets = d.get("pellets", 1); w.spread = d.get("spread", 0.0)
			w.slow_time = d.get("slow_time", 0.0); w.slow_factor = d.get("slow_factor", 1.0)
			w.charge_time = d.get("charge_time", 0.0); w.min_charge = d.get("min_charge", 0.0)
			w.hidden = d.get("hidden", false)
			_registry[k] = w
	return _registry.get(wid, _registry[&"bubble_gun"])

static func selectable_ids() -> Array:
	var out := []
	for k in Balance.WEAPONS:
		if not Balance.WEAPONS[k].get("hidden", false):
			out.append(k)
	return out

## damage after charge (charge 0..1); non-charge weapons ignore it
func damage_for(charge: float) -> int:
	if charge_time <= 0.0:
		return damage
	return roundi(damage * lerpf(min_charge, 1.0, clampf(charge, 0.0, 1.0)))
