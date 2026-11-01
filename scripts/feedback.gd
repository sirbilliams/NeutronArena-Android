class_name Feedback
extends Control
## Owner-side combat feedback layered on the HUD: crosshair hit marker, floating damage numbers, kill feed (top right),
## low-HP red vignette with heartbeat pulse, damage direction indicators. All plain Controls / Label3D (no custom shaders).
var world: World
var marker_t := 0.0
var marker_kill := false
var vignette: TextureRect
var feed: VBoxContainer
var inds: Array[Polygon2D] = []
var ind_t: Array[float] = []
var ind_next := 0
var hb_t := 0.0
const FEED_MAX := 5
const FEED_LIFE := 5.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.45, 1.0])
	g.colors = PackedColorArray([Color(0.9, 0.0, 0.0, 0.0), Color(0.9, 0.0, 0.05, 0.85)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	vignette = TextureRect.new()
	vignette.texture = gt
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	add_child(vignette)
	for i in 4:
		var pg := Polygon2D.new()
		pg.polygon = PackedVector2Array([Vector2(-26, -135), Vector2(26, -135), Vector2(0, -175)])
		pg.color = Color(1, 0.1, 0.1, 0.9)
		pg.visible = false
		add_child(pg)
		inds.append(pg)
		ind_t.append(0.0)
	feed = VBoxContainer.new()
	feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	feed.position = Vector2(-12, 44)
	feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(feed)
	world.hit_event.connect(_on_hit)
	world.player_died.connect(_on_died)

func _me() -> Player:
	return world.players.get(multiplayer.get_unique_id()) if multiplayer.has_multiplayer_peer() else null

func _on_hit(victim: int, shooter: int, dmg: int, pos: Vector3, killed: bool) -> void:
	var my_id := multiplayer.get_unique_id()
	if shooter == my_id and victim != my_id:
		marker_t = 0.5 if killed else 0.25
		marker_kill = killed
		_damage_number(pos, dmg, killed)
	if victim == my_id and shooter != my_id:
		var me := _me()
		var sp: Player = world.players.get(shooter)
		if me and sp and me.is_local:
			var d := sp.global_position - me.global_position
			var cy := me.cam_yaw
			var fwd := Vector3(-sin(cy), 0.0, -cos(cy))
			var right := Vector3(cos(cy), 0.0, -sin(cy))
			_indicator(atan2(d.dot(right), d.dot(fwd)))
		hb_t = 0.0
		vignette.modulate.a = maxf(vignette.modulate.a, 0.35)   # brief hurt flash on top of the low-HP pulse

func _indicator(ang: float) -> void:
	var i := ind_next
	ind_next = (ind_next + 1) % inds.size()
	ind_t[i] = 1.2
	inds[i].rotation = ang
	inds[i].visible = true

func _damage_number(pos: Vector3, dmg: int, killed: bool) -> void:
	var l := Label3D.new()
	l.text = str(dmg)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.0045 * (1.0 + minf(dmg, 70) / 70.0)
	l.font_size = 64
	l.outline_size = 14
	l.modulate = Color(1.0, 0.25, 0.2) if killed else Color(1.0, 0.95, 0.5)
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.render_priority = 6
	l.position = pos + Vector3(randf_range(-0.2, 0.2), 0.3, randf_range(-0.2, 0.2))
	world.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 0.9, 0.75).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.4)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.35).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)

func _on_died(id: int, killer: int) -> void:
	var v: Player = world.players.get(id)
	var k: Player = world.players.get(killer)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.add_child(_name_label(k, killer))
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.15), Color(0.6, 0.9, 1.0, 0.45), Color(1, 1, 1, 0.95)])
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 32
	gt.height = 32
	var icon := TextureRect.new()
	icon.texture = gt
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(_name_label(v, id))
	feed.add_child(row)
	feed.move_child(row, 0)
	while feed.get_child_count() > FEED_MAX:
		feed.get_child(feed.get_child_count() - 1).queue_free()
		feed.remove_child(feed.get_child(feed.get_child_count() - 1))
	get_tree().create_timer(FEED_LIFE).timeout.connect(func():
		if is_instance_valid(row):
			row.queue_free())

func _name_label(p: Player, id: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	if p:
		l.text = "%s_%d" % [Config.TEAM_NAMES[p.team], id]
		l.add_theme_color_override("font_color", Config.TEAM_COLORS[p.team])
	else:
		l.text = "WORLD" if id == 0 else "PLAYER_%d" % id
	return l

func _process(dt: float) -> void:
	size = get_viewport_rect().size   # under a CanvasLayer the anchors do not resolve to the viewport
	feed.position = Vector2(size.x - feed.size.x - 12.0, 44.0)
	vignette.size = size
	marker_t = maxf(0.0, marker_t - dt)
	queue_redraw()
	for i in inds.size():
		ind_t[i] = maxf(0.0, ind_t[i] - dt)
		inds[i].visible = ind_t[i] > 0.0
		inds[i].modulate.a = clampf(ind_t[i] / 0.8, 0.0, 1.0)
		inds[i].position = size * 0.5
	var me := _me()
	var target := 0.0
	if me and me.alive and not world.match_over:
		var frac := float(me.hp) / maxf(me.max_hp, 1)
		if frac < 0.4:
			hb_t += dt * (1.1 + (0.4 - frac) * 4.0)
			var t := fposmod(hb_t, 1.0)
			var beat := exp(-t * 9.0) + (0.6 * exp(-(t - 0.3) * 9.0) if t > 0.3 else 0.0)
			target = ((0.4 - frac) / 0.4 * 0.6 + 0.25) * (0.4 + 0.6 * beat)
	vignette.modulate.a = move_toward(vignette.modulate.a, target, dt * (0.6 if vignette.modulate.a > target else 3.0))

func _draw() -> void:
	if marker_t <= 0.0:
		return
	var c := size * 0.5
	var col := Color(1, 0.12, 0.1) if marker_kill else Color.WHITE
	col.a = clampf(marker_t / 0.15, 0.0, 1.0)
	var gap := 7.0 + (1.0 - marker_t / (0.5 if marker_kill else 0.25)) * 3.0
	var ln := 13.0 if marker_kill else 10.0
	for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		draw_line(c + d * gap, c + d * (gap + ln), col, 3.0 if marker_kill else 2.5, true)
