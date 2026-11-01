class_name Scoreboard
extends CanvasLayer
## Hold Tab (gamepad Start) to see both teams: kills/deaths per player, bots marked [BOT].
var world: World
var label: Label
var panel: PanelContainer

func _ready() -> void:
	layer = 5
	panel = PanelContainer.new()
	panel.theme_type_variation = &"ScoreboardPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-300, -170)
	panel.visible = false
	label = Label.new()
	label.theme_type_variation = &"Mono"
	panel.add_child(label)
	add_child(panel)

func _process(_d: float) -> void:
	var show := Input.is_key_pressed(KEY_TAB)
	for d in Input.get_connected_joypads():
		show = show or Input.is_joy_button_pressed(d, JOY_BUTTON_START)
	panel.visible = show
	if show and world:
		label.text = text()

func text() -> String:
	var out := "%s %d   -   %d %s\n" % [Config.TEAM_NAMES[0], world.team_score[0], world.team_score[1], Config.TEAM_NAMES[1]]
	for t in 2:
		out += "\n%s\n" % Config.TEAM_NAMES[t]
		var ids := []
		for id in world.players:
			if world.players[id].team == t:
				ids.append(id)
		ids.sort_custom(func(a, b): return world.kills.get(a, 0) > world.kills.get(b, 0))
		for id in ids:
			out += "  %-12s K %2d  D %2d\n" % [("[BOT] %d" % -id) if id < 0 else ("Player %d" % id), world.kills.get(id, 0), world.deaths.get(id, 0)]
	var me: Player = world.players.get(multiplayer.get_unique_id())
	if me:   # device diagnostics: which clips were turned, and the facing numbers while moving
		out += "\nfacing fixes: %s   model %.0f  cam %.0f  clip %s" % [", ".join(AnimFix.turned) if AnimFix.turned else "none", rad_to_deg(me.model_yaw), rad_to_deg(me.cam_yaw), me.anim.current_animation if me.anim else "-"]
	return out
