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

var asset_dir := ""
var last_ip := "127.0.0.1"
var test_mode := false   # headless tests: no local input

func _ready() -> void:
	asset_dir = OS.get_environment("HOME").path_join("Projects/arena-assets")
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK:
		asset_dir = cf.get_value("game", "asset_dir", asset_dir)
		last_ip = cf.get_value("game", "last_ip", last_ip)
	var env := OS.get_environment("NEGATRON_ASSETS")
	if env != "":
		asset_dir = env
	_setup_input()

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "asset_dir", asset_dir)
	cf.set_value("game", "last_ip", last_ip)
	cf.save(SETTINGS)

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
