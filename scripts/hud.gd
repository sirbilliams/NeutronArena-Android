class_name Hud
extends CanvasLayer
## Score / HP / respawn / winner HUD.
var world: World
var score_label: Label
var hp_bar: ProgressBar
var info_label: Label
var banner: Label
var cross: Label
var kd_label: Label

func _ready() -> void:
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	score_label.position = Vector2(-180, 10)
	add_child(score_label)
	hp_bar = ProgressBar.new()
	hp_bar.max_value = Config.MAX_HP
	hp_bar.custom_minimum_size = Vector2(260, 22)
	hp_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hp_bar.position = Vector2(30, -50)
	add_child(hp_bar)
	kd_label = Label.new()
	kd_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	kd_label.position = Vector2(30, -80)
	add_child(kd_label)
	cross = Label.new()
	cross.text = "+"
	cross.add_theme_font_size_override("font_size", 28)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(8, -18)
	add_child(cross)
	banner = Label.new()
	banner.add_theme_font_size_override("font_size", 44)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.position = Vector2(-250, -140)
	add_child(banner)
	info_label = Label.new()
	info_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	info_label.position = Vector2(10, 10)
	add_child(info_label)

func _process(_d: float) -> void:
	if world == null or not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	score_label.text = "JIMMY %d  -  %d NEGATRON   (first to %d)" % [world.team_score[0], world.team_score[1], Config.WIN_SCORE]
	var me: Player = world.players.get(multiplayer.get_unique_id())
	info_label.text = "players: %d   %s" % [world.players.size(), "host" if multiplayer.is_server() else "client"]
	if me:
		hp_bar.value = me.hp
		kd_label.text = "%s   kills %d  deaths %d" % [Config.TEAM_NAMES[me.team], world.kills.get(me.peer_id, 0), world.deaths.get(me.peer_id, 0)]
		cross.visible = me.alive and not world.match_over
		if world.match_over:
			banner.text = "%s TEAM WINS!" % Config.TEAM_NAMES[world.winner]
		elif not me.alive:
			banner.text = "Respawning..."
		else:
			banner.text = ""
