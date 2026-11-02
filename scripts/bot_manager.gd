class_name BotManager
extends Node
## Server only. Keeps both teams filled to World.TEAM_CAP with bots (one new bot per 0.25 s, never before a human is in),
## and ticks every BotBrain each physics frame (brains think at THINK_HZ, apply smoothed inputs every frame).
var world: World
var enabled := true
var difficulty := "normal"
var brains := {}          # bot id -> BotBrain
var nav: BotNav
var fill_t := 0.0
var stat_us := 0.0        # accumulated microseconds spent in brains
var stat_frames := 0
var stat_peak_us := 0

func _ready() -> void:
	nav = BotNav.new(world.level.layout_name)

## Map changed (World._srv_begin_round): new route for every brain.
func set_map(layout: String) -> void:
	nav = BotNav.new(layout)
	for id in brains:
		brains[id].nav = nav

func forget(id: int) -> void:
	brains.erase(id)

func _humans() -> int:
	var n := 0
	for i in world.info:
		if i > 0:
			n += 1
	return n

func _fill() -> void:
	if world.match_over or _humans() == 0:
		return
	var counts := world._team_counts()
	for t in 2:
		if counts[t] < World.TEAM_CAP:
			var id := world.srv_add_bot(t)
			if id != 0:
				var b := BotBrain.new()
				b.id = id
				b.world = world
				b.nav = nav
				b.set_difficulty(difficulty)
				brains[id] = b
			return

func _physics_process(dt: float) -> void:
	if not world.net_ready() or not multiplayer.is_server():
		return
	if not enabled:
		for id in world.srv_bot_ids():
			world.srv_remove_bot(id)
		return
	fill_t -= dt
	if fill_t <= 0.0:
		fill_t = 0.25
		_fill()
	var t0 := Time.get_ticks_usec()
	var now := Time.get_ticks_msec() / 1000.0
	for id in brains:
		var b: BotBrain = brains[id]
		b.player = world.players.get(id)
		if b.player != null:
			b.tick(dt, now)
	var us := Time.get_ticks_usec() - t0
	stat_us += us
	stat_frames += 1
	stat_peak_us = maxi(stat_peak_us, us)

## Mean milliseconds per physics frame spent on all bots since the last call.
func take_avg_ms() -> float:
	var r := stat_us / 1000.0 / maxf(stat_frames, 1)
	stat_us = 0.0
	stat_frames = 0
	return r
