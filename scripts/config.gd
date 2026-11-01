extends Node
## Autoload "Config": constants, user settings, input map.
const WORLD_SCALE := 0.0066      # raw game units -> metres (Jimmy 213 units = 1.4 m)
const PORT := 24680
const MAX_PLAYERS := 10
const WIN_SCORE := 25
const RESPAWN_TIME := 3.0
const MAX_HP := 100
const TEAM_JIMMY := 0
const TEAM_NEGATRON := 1
const TEAM_NAMES := ["JIMMY", "NEGATRON"]
const TEAM_COLORS := [Color(0.25, 0.65, 1.0), Color(0.85, 0.25, 0.95)]
const SETTINGS := "user://settings.cfg"

var asset_dir := ""          # where the glb files are read from (imported ones, or a dev folder)
var dev_asset_dir := ""      # optional: a folder with exported glbs (dev fallback, the old way)
var last_ip := "127.0.0.1"
var test_mode := false   # headless tests: no local input
const BEACON_PORT := 7778    # LAN discovery (UDP broadcast, scripts/lan_beacon.gd)
var beacon_port := BEACON_PORT
var bots_enabled := true     # host option: fill both teams to 5 with bots
var bot_difficulty := "normal"   # easy / normal / hard
var last_loadout := {}       # last confirmed loadout (Quick Play reuses it)

## Android: folders searched for the game export (first one that has the files wins). Needs "All files access"
## (or adb push into the app folder below, which needs no permission).
const ANDROID_ASSET_DIRS := [
	"/sdcard/NeutronArena",
	"/storage/emulated/0/NeutronArena",
	"/sdcard/Android/data/com.neutronarena.game/files/NeutronArena",
]

## Art imported on the device from the player's own game CDs (scripts/setup_screen.gd -> NaImporter). Never committed.
const IMPORT_URL := "user://imported"
const IMPORT_VERSION := 1

func import_dir() -> String:
	return ProjectSettings.globalize_path(IMPORT_URL)

## True when a complete import is in place (marker written by the setup screen after a successful run).
func imported_ok() -> bool:
	var cf := ConfigFile.new()
	return cf.load(IMPORT_URL.path_join("import.cfg")) == OK and int(cf.get_value("import", "version", 0)) == IMPORT_VERSION \
		and FileAccess.file_exists(import_dir().path_join("levels/level5c.glb")) and FileAccess.file_exists(import_dir().path_join("jimmy.glb"))

## True when the Boy Genius disc was imported too (N1 gadget models).
func has_n1() -> bool:
	return FileAccess.file_exists(asset_path("ase/n1/strato.glb"))

func _ready() -> void:
	dev_asset_dir = OS.get_environment("HOME").path_join("Projects/arena-assets")
	if OS.get_name() == "Android":
		dev_asset_dir = ANDROID_ASSET_DIRS[0]
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK:
		dev_asset_dir = cf.get_value("game", "asset_dir", dev_asset_dir)
		last_ip = cf.get_value("game", "last_ip", last_ip)
		bots_enabled = cf.get_value("game", "bots", bots_enabled)
		bot_difficulty = cf.get_value("game", "bot_difficulty", bot_difficulty)
		last_loadout = cf.get_value("game", "last_loadout", last_loadout)
	asset_dir = dev_asset_dir
	if imported_ok():
		asset_dir = import_dir()
	var env := OS.get_environment("NEUTRON_ASSETS")
	if env != "":
		asset_dir = env
	elif OS.get_name() == "Android" and not assets_ok():
		find_android_assets()
	_setup_input()

## Called after a (re-)import: use the imported files.
func use_imported() -> void:
	asset_dir = import_dir()

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "asset_dir", dev_asset_dir)
	cf.set_value("game", "last_ip", last_ip)
	cf.set_value("game", "bots", bots_enabled)
	cf.set_value("game", "bot_difficulty", bot_difficulty)
	cf.set_value("game", "last_loadout", last_loadout)
	cf.save(SETTINGS)

## Android: ask for storage access (runtime + All-files access declared in the export preset).
func request_android_storage() -> void:
	if OS.get_name() == "Android" and not imported_ok():
		OS.request_permissions()

## Android: switch asset_dir to the first candidate folder that holds the game files; returns true if found.
func find_android_assets() -> bool:
	for d in [asset_dir] + ANDROID_ASSET_DIRS:
		var old := asset_dir
		asset_dir = d
		if assets_ok():
			return true
		asset_dir = old
	return false

func asset_path(rel: String) -> String:
	return asset_dir.path_join(rel)

func assets_ok() -> bool:
	return FileAccess.file_exists(asset_path("levels/level5c.glb")) and FileAccess.file_exists(asset_path("jimmy.glb"))

func _key(action: String, k: Key) -> void:
	var e := InputEventKey.new(); e.physical_keycode = k
	InputMap.action_add_event(action, e)

func _btn(action: String, b: JoyButton) -> void:
	var e := InputEventJoypadButton.new(); e.button_index = b
	InputMap.action_add_event(action, e)

func _axis(action: String, a: JoyAxis, v: float) -> void:
	var e := InputEventJoypadMotion.new(); e.axis = a; e.axis_value = v
	InputMap.action_add_event(action, e)

func _setup_input() -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back", "look_left", "look_right", "look_up", "look_down", "jump", "fire", "gadget", "movement", "ultimate", "loadout_menu"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
	_key("move_left", KEY_A); _key("move_right", KEY_D); _key("move_forward", KEY_W); _key("move_back", KEY_S)
	_key("jump", KEY_SPACE)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0); _axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0); _axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_axis("look_left", JOY_AXIS_RIGHT_X, -1.0); _axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0); _axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_btn("jump", JOY_BUTTON_A)
	_key("gadget", KEY_Q); _btn("gadget", JOY_BUTTON_LEFT_SHOULDER)
	_key("movement", KEY_SHIFT); _btn("movement", JOY_BUTTON_RIGHT_SHOULDER)
	_key("ultimate", KEY_F)   # gamepad: LB+RB together (handled in Player)
	_key("loadout_menu", KEY_L); _btn("loadout_menu", JOY_BUTTON_BACK)
	_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	var m := InputEventMouseButton.new(); m.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", m)
