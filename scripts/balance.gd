class_name Balance
extends RefCounted
## ALL loadout balance numbers live here (weapons, gadgets, movement, ultimates, classes). Pure data.
const WEAPONS := {
	&"bubble_gun": {"name": "Bubble Gun", "desc": "All-rounder. Reliable bubbles.", "damage": 20, "speed": 30.0, "radius": 0.15, "lifetime": 2.5, "interval": 0.3},
	&"burp_gun": {"name": "Burp Gun", "desc": "Short-range spread blast.", "damage": 9, "speed": 38.0, "radius": 0.12, "lifetime": 0.45, "interval": 0.75, "pellets": 7, "spread": 0.09},
	&"water_gun": {"name": "Water Gun", "desc": "Fast stream. Slows the target.", "damage": 4, "speed": 34.0, "radius": 0.10, "lifetime": 1.1, "interval": 0.08, "slow_time": 1.5, "slow_factor": 0.6},
	&"mega_burp": {"name": "Mega Burp Gun", "desc": "Hold to charge. Heavy hit.", "damage": 70, "speed": 24.0, "radius": 0.35, "lifetime": 2.0, "interval": 1.2, "charge_time": 1.0, "min_charge": 0.35},
	&"baseball": {"name": "Baseball Launcher", "desc": "Arcing lob.", "damage": 35, "speed": 22.0, "radius": 0.20, "lifetime": 4.0, "interval": 0.8, "gravity": 14.0},
	&"rocket": {"name": "Rocket", "desc": "Rocket ship ultimate.", "damage": 45, "speed": 42.0, "radius": 0.25, "lifetime": 2.5, "interval": 0.35, "hidden": true},
}
const GADGETS := {
	&"shrink_ray": {"name": "Shrink Ray", "desc": "Target shrinks 4 s: slower, takes +50% damage.", "cooldown": 10.0, "duration": 4.0, "dmg_mult": 1.5, "slow": 0.7, "range": 30.0},
	&"energy_shield": {"name": "Energy Shield", "desc": "Bubble absorbs 60 damage for 5 s.", "cooldown": 14.0, "duration": 5.0, "absorb": 60},
	&"laser_trap": {"name": "Laser Trap", "desc": "Place a tripwire ahead. 35 damage.", "cooldown": 12.0, "damage": 35, "life": 40.0, "max_traps": 2, "width": 4.0, "dist": 2.5},
	&"drone": {"name": "Goddard Drone", "desc": "Marks nearby enemies through walls.", "cooldown": 18.0, "duration": 6.0, "radius": 30.0},
	&"power_phase": {"name": "Power Phase", "desc": "3 s invulnerable, cannot shoot.", "cooldown": 20.0, "duration": 3.0},
}
const MOVEMENTS := {
	&"none": {"name": "Heavy Plating", "desc": "No movement ability. +50 HP.", "hp_bonus": 50},
	&"sprint": {"name": "Sprint", "desc": "Hold to run faster.", "speed_mult": 1.6},
	&"jetpack": {"name": "Jetpack", "desc": "Hold to fly. Fuel bar.", "fuel": 100.0, "drain": 45.0, "regen": 30.0, "thrust": 30.0, "max_up": 7.0},
	&"goof_boots": {"name": "Goof Boots", "desc": "Double jump + glide (hold jump).", "extra_jumps": 1, "glide_fall": 2.5},
	&"grapple": {"name": "Grappling Hook", "desc": "Pull yourself to the surface you aim at.", "range": 40.0, "speed": 26.0, "cooldown": 2.5, "max_time": 1.5},
	&"bubble_float": {"name": "Bubble Float", "desc": "Hold to hover slowly down.", "fuel": 100.0, "drain": 30.0, "regen": 25.0, "fall": 1.2},
}
const ULTIMATES := {
	&"rocket_ship": {"name": "Rocket Ship", "desc": "Fly and fire rockets for 8 s.", "cost": 200, "duration": 8.0, "fly_speed": 13.0, "weapon": &"rocket"},
	&"goddard_scooter": {"name": "Goddard Scooter", "name_negatron": "Negatron Scooter", "desc": "Fast vehicle, ram enemies for 8 s.", "cost": 200, "duration": 8.0, "speed_mult": 2.4, "ram_damage": 45, "ram_interval": 0.8, "ram_radius": 1.8},
}
## slot order: primary, gadget, movement, ultimate
const CLASSES := {
	&"inventor": {"name": "Inventor", "primary": &"bubble_gun", "gadget": &"energy_shield", "movement": &"sprint", "ultimate": &"rocket_ship"},
	&"blaster": {"name": "Blaster", "primary": &"burp_gun", "gadget": &"shrink_ray", "movement": &"goof_boots", "ultimate": &"goddard_scooter"},
	&"sky_jockey": {"name": "Sky Jockey", "primary": &"bubble_gun", "gadget": &"laser_trap", "movement": &"jetpack", "ultimate": &"rocket_ship"},
	&"mastermind": {"name": "Mastermind", "primary": &"water_gun", "gadget": &"drone", "movement": &"sprint", "ultimate": &"goddard_scooter"},
	&"heavy": {"name": "Heavy", "primary": &"mega_burp", "gadget": &"energy_shield", "movement": &"none", "ultimate": &"goddard_scooter"},
}
const DEFAULT_CLASS := &"inventor"
const SLOTS := [&"primary", &"gadget", &"movement", &"ultimate"]
const SPRINT_ALL := 1.0
