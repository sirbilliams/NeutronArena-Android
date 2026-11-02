class_name GameMode
extends RefCounted
## Base class of a game mode (one script per mode: mode_tdm / mode_gun_game / mode_ctf / mode_koth; registry in modes.gd).
## Pure rules: no nodes, no RPCs, so tests/run_modes_test.sh can drive them with fake player lists.
## The server (World) calls on_kill / on_death / tick and reads result(); every peer renders from state() / apply_state().
## `ps` = Array of {id, team, pos: Vector3, alive: bool} built by World.
var id: StringName = &"tdm"
var display_name := "Team Deathmatch"
var desc := ""
var scores := [0, 0]            # team score shown at the top (kills / captures / hill points)
var dirty_loadouts: Array = []  # player ids whose loadout the mode changed (server pushes them to peers)

## Gun Game turns the gadget and the ultimate off.
func gadgets_allowed() -> bool:
	return true

## Mode override on a loadout the server is about to apply (Gun Game forces the primary weapon).
func loadout_for(_pid: int, lo: Dictionary) -> Dictionary:
	return lo

## Server: `killer` (0 = none) killed `victim`. Returns feed messages (Array of String).
func on_kill(_killer: int, _killer_team: int, _victim: int, _victim_team: int) -> Array:
	return []

## Server: a player died (any cause) at `pos`.
func on_death(_pid: int, _pos: Vector3) -> Array:
	return []

## Server: per physics step.
func tick(_dt: float, _ps: Array) -> Array:
	return []

## {} while running, else {team: winning team or -1, player: winning peer or 0, text: banner}.
func result() -> Dictionary:
	return {}

func reset() -> void:
	scores = [0, 0]
	dirty_loadouts.clear()

func take_dirty() -> Array:
	var d := dirty_loadouts
	dirty_loadouts = []
	return d

## Replicated state (only what clients need to draw the HUD / flags / zone).
func state() -> Dictionary:
	return {}

func apply_state(_d: Dictionary) -> void:
	pass

func score_line() -> String:
	return "JIMMY %d  -  %d NEGATRON" % [scores[0], scores[1]]

## Second HUD line: objective status for the local player.
func objective_text(_pid: int, _team: int) -> String:
	return ""

## Scoreboard column text for one player ("" = nothing).
func board_extra(_pid: int) -> String:
	return ""

## Bots: where should this bot go? Vector3, or null = just fight / follow the street.
func bot_goal(_pid: int, _team: int, _pos: Vector3) -> Variant:
	return null

## Bots: ignore enemies for movement (flag carrier running home).
func bot_rush(_pid: int) -> bool:
	return false

## Placement info from the level (flag homes, hill centre); called on every peer when a round starts.
func setup_level(_level: ArenaLevel) -> void:
	pass
