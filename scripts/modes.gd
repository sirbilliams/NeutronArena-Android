class_name Modes
extends RefCounted
## Mode registry. Add a mode: write mode_<x>.gd (extends GameMode), register it here.
const IDS: Array[StringName] = [&"tdm", &"gun_game", &"ctf", &"koth"]

static func create(mid: StringName) -> GameMode:
	match mid:
		&"gun_game": return ModeGunGame.new()
		&"ctf": return ModeCtf.new()
		&"koth": return ModeKoth.new()
	return ModeTdm.new()

static func valid(mid: StringName) -> bool:
	return IDS.has(mid)

static func name_of(mid: StringName) -> String:
	return create(mid).display_name

static func desc_of(mid: StringName) -> String:
	return create(mid).desc
