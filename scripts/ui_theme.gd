class_name UiTheme
extends RefCounted
## Menu / HUD look, built from code: one Godot Theme per theme id (StyleBoxFlat, procedural icons, default or system fonts,
## no shipped art). `apply(id)` installs the Theme into the engine default theme, so every Control in the game inherits it,
## whatever node it hangs under (CanvasLayers and plain Nodes break Window.theme inheritance), and refreshes the live tree.
## Screens pick semantic looks with `theme_type_variation` (Title, MenuPanel, PrimaryButton, HpBar, ...); the HUD reads the
## semantic colours with `col()` / `team_color()`. Theme ids are saved by Config (settings.cfg [ui] theme).

const IDS: Array[StringName] = [&"lab", &"negatron", &"candy", &"yokian", &"cartoon"]
const NAMES := {
	&"lab": "Retroville Lab",
	&"negatron": "Negatron Overdrive",
	&"candy": "Candy Bar Pop",
	&"yokian": "Yokian Space",
	&"cartoon": "Saturday Cartoon",
}
const DEFAULT := &"lab"

static var current: StringName = DEFAULT
static var _pal := {}
static var _font_cache := {}

## Semantic colour of the active theme (bg, panel, accent, accent2, text, text_dim, danger, warning, success, focus,
## team_jimmy, team_negatron, hp, fuel, ult, ult_ready, overlay, outline).
static func col(key: StringName) -> Color:
	if _pal.is_empty():
		_pal = palette(current)
	return _pal.get(key, Color.MAGENTA)

static func team_color(team: int) -> Color:
	return col(&"team_jimmy") if team == Config.TEAM_JIMMY else col(&"team_negatron")

static func display_name(id: StringName) -> String:
	return NAMES.get(id, str(id))

static func valid(id: StringName) -> bool:
	return IDS.has(id)

## Install theme `id` for the whole game (live: every Control re-reads its theme items).
static func apply(id: StringName) -> void:
	if not valid(id):
		id = DEFAULT
	current = id
	_pal = palette(id)
	var t := build(id)
	var d := ThemeDB.get_default_theme()
	d.merge_with(t)
	d.default_font = t.default_font
	d.default_font_size = t.default_font_size
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		for c in tree.root.find_children("*", "Control", true, false):
			c.notification(Control.NOTIFICATION_THEME_CHANGED)
		for w in tree.root.find_children("*", "Window", true, false):
			w.notification(Window.NOTIFICATION_THEME_CHANGED)

# ---------------------------------------------------------------------------------------------------------------------
# Palettes + shape language

static func palette(id: StringName) -> Dictionary:
	var p := {}
	match id:
		&"negatron":
			p = {
				bg = Color("#07050a"), bg2 = Color("#2a0810"), panel = Color("#120a10", 0.94), panel_border = Color("#ff2a3c"),
				surface = Color("#1d1016"), surface_hover = Color("#33161f"), surface_pressed = Color("#ff2a3c"), surface_disabled = Color("#140d11"),
				accent = Color("#ff2a3c"), accent2 = Color("#c21bff"), text = Color("#f4e9ea"), text_dim = Color("#9a8690"), text_on_accent = Color("#fff5f5"),
				text_disabled = Color("#5c4a52"), danger = Color("#ff5a3c"), warning = Color("#ffb347"), success = Color("#7cff6b"), focus = Color("#ff4b5c"),
				field = Color("#0c080b"), team_jimmy = Color("#56b8ff"), team_negatron = Color("#ff3f8f"), hp = Color("#ff2a3c"), fuel = Color("#ff9a2a"),
				ult = Color("#c21bff"), ult_ready = Color("#ff2a3c"), overlay = Color("#05030a", 0.9), outline = Color("#000000", 0.95), bar_bg = Color("#1a0d13"),
			}
		&"candy":
			p = {
				bg = Color("#ffd6e8"), bg2 = Color("#d9c6ff"), panel = Color("#fff8fc", 0.97), panel_border = Color("#ff8ec4"),
				surface = Color("#ffe9f3"), surface_hover = Color("#ffd1e6"), surface_pressed = Color("#ff5fa8"), surface_disabled = Color("#f3e6ec"),
				accent = Color("#ff4f9f"), accent2 = Color("#2cc8a8"), text = Color("#4a2040"), text_dim = Color("#8d6a82"), text_on_accent = Color("#ffffff"),
				text_disabled = Color("#b9a3b1"), danger = Color("#e0325a"), warning = Color("#d9820b"), success = Color("#1fae80"), focus = Color("#6a2cb8"),
				field = Color("#fff2f8"), team_jimmy = Color("#2f8cff"), team_negatron = Color("#b23bd6"), hp = Color("#ff4f9f"), fuel = Color("#ffb020"),
				ult = Color("#2cc8a8"), ult_ready = Color("#ffd400"), overlay = Color("#f6d8e8", 0.93), outline = Color("#3a1030", 0.9), bar_bg = Color("#f1dbe7"),
			}
		&"yokian":
			p = {
				bg = Color("#05031a"), bg2 = Color("#1a0b3e"), panel = Color("#120a33", 0.93), panel_border = Color("#9dff3a"),
				surface = Color("#1d1250"), surface_hover = Color("#2c1c70"), surface_pressed = Color("#9dff3a"), surface_disabled = Color("#150f36"),
				accent = Color("#9dff3a"), accent2 = Color("#8a4dff"), text = Color("#ecebff"), text_dim = Color("#9d94c8"), text_on_accent = Color("#0a1402"),
				text_disabled = Color("#5a527c"), danger = Color("#ff4d6a"), warning = Color("#ffc857"), success = Color("#9dff3a"), focus = Color("#c6ff6b"),
				field = Color("#0c0826"), team_jimmy = Color("#4fb8ff"), team_negatron = Color("#ff4fd8"), hp = Color("#9dff3a"), fuel = Color("#ffc857"),
				ult = Color("#8a4dff"), ult_ready = Color("#9dff3a"), overlay = Color("#05031a", 0.9), outline = Color("#04021a", 0.95), bar_bg = Color("#150f3d"),
			}
		&"cartoon":
			p = {
				bg = Color("#47b5ff"), bg2 = Color("#1f7ee0"), panel = Color("#fff1a8"), panel_border = Color("#161628"),
				surface = Color("#ff8c1a"), surface_hover = Color("#ffd000"), surface_pressed = Color("#ff3b3b"), surface_disabled = Color("#d8cfa8"),
				accent = Color("#ff3b3b"), accent2 = Color("#ffd000"), text = Color("#161628"), text_dim = Color("#4f4f68"), text_on_accent = Color("#161628"),
				text_disabled = Color("#8a8a7a"), danger = Color("#d61f1f"), warning = Color("#c75c00"), success = Color("#1e9e4a"), focus = Color("#161628"),
				field = Color("#ffffff"), team_jimmy = Color("#1f7ee0"), team_negatron = Color("#b1319e"), hp = Color("#2fd35a"), fuel = Color("#ff8c1a"),
				ult = Color("#1f7ee0"), ult_ready = Color("#ffd000"), overlay = Color("#8fd0ff", 0.93), outline = Color("#161628"), bar_bg = Color("#fff8d8"),
			}
		_:   # lab
			p = {
				bg = Color("#07131f"), bg2 = Color("#0f2a44"), panel = Color("#0b1b2e", 0.92), panel_border = Color("#38d9ff"),
				surface = Color("#10263d"), surface_hover = Color("#173753"), surface_pressed = Color("#38d9ff"), surface_disabled = Color("#0d1c2c"),
				accent = Color("#38d9ff"), accent2 = Color("#ffb347"), text = Color("#e6f4ff"), text_dim = Color("#8aa6bf"), text_on_accent = Color("#03131f"),
				text_disabled = Color("#48607a"), danger = Color("#ff6a5c"), warning = Color("#ffb347"), success = Color("#5cff9d"), focus = Color("#7ff0ff"),
				field = Color("#061220"), team_jimmy = Color("#40a6ff"), team_negatron = Color("#e04bff"), hp = Color("#38d9ff"), fuel = Color("#ffb347"),
				ult = Color("#5c7cff"), ult_ready = Color("#ffd166"), overlay = Color("#04101c", 0.9), outline = Color("#021018", 0.95), bar_bg = Color("#0a1828"),
			}
	return p

## Shape / type language of a theme.
static func _spec(id: StringName) -> Dictionary:
	match id:
		&"negatron":
			return {radius = 0, border = 2, skew = -0.18, shadow = 0, shadow_off = Vector2.ZERO, glow = 12, title_size = 48, title_outline = 0,
				heading = _sys(["Noto Sans", "Roboto", "DejaVu Sans", "sans-serif"], 900, 0.0, 0.0), heading_skew = -0.22,
				body = _var(0.2, 0.0), button = _sys(["Noto Sans", "Roboto", "DejaVu Sans", "sans-serif"], 800, 0.0, 0.0), mono = _mono(),
				accent_stripe = 0, hud_outline = 5}
		&"candy":
			return {radius = 22, border = 2, skew = 0.0, shadow = 14, shadow_off = Vector2(0, 6), glow = 10, title_size = 46, title_outline = 0,
				heading = _sys(["Noto Sans", "Roboto", "DejaVu Sans", "sans-serif"], 800, 0.0, 0.0), heading_skew = 0.0,
				body = _var(0.0, 0.0), button = _sys(["Noto Sans", "Roboto", "DejaVu Sans", "sans-serif"], 700, 0.0, 0.0), mono = _mono(),
				accent_stripe = 0, hud_outline = 5}
		&"yokian":
			return {radius = 8, border = 1, skew = 0.0, shadow = 18, shadow_off = Vector2(0, 0), glow = 14, title_size = 46, title_outline = 6,
				heading = _sys(["Noto Sans", "Roboto", "DejaVu Sans", "sans-serif"], 800, 0.0, 0.0), heading_skew = 0.0,
				body = _var(0.0, 0.0), button = _sys(["Noto Sans", "Roboto", "DejaVu Sans", "sans-serif"], 700, 0.0, 0.0), mono = _mono(),
				accent_stripe = 0, hud_outline = 5}
		&"cartoon":
			return {radius = 12, border = 4, skew = 0.0, shadow = 2, shadow_off = Vector2(6, 6), glow = 0, title_size = 50, title_outline = 8,
				heading = _sys(["Noto Sans", "Roboto", "DejaVu Sans", "sans-serif"], 900, 0.0, 0.0), heading_skew = -0.12,
				body = _var(0.25, 0.0), button = _sys(["Noto Sans", "Roboto", "DejaVu Sans", "sans-serif"], 900, 0.0, 0.0), mono = _mono(),
				accent_stripe = 0, hud_outline = 6}
		_:
			return {radius = 4, border = 1, skew = 0.0, shadow = 0, shadow_off = Vector2.ZERO, glow = 10, title_size = 44, title_outline = 0,
				heading = _mono(700, 2.0), heading_skew = 0.0,
				body = _var(0.0, 0.0), button = _var(0.3, 1.0), mono = _mono(),
				accent_stripe = 4, hud_outline = 5}

# ---------------------------------------------------------------------------------------------------------------------
# Fonts: only the engine default (Open Sans) and the device's system fonts, with variations.

static func _var(embolden: float, spacing: float, skew: float = 0.0) -> Font:
	var key := "var|%s|%s|%s" % [embolden, spacing, skew]
	if _font_cache.has(key):
		return _font_cache[key]
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = embolden
	f.spacing_glyph = int(spacing)
	if skew != 0.0:
		f.variation_transform = Transform2D(Vector2(1, 0), Vector2(skew, 1), Vector2.ZERO)
	_font_cache[key] = f
	return f

static func _sys(names: Array, weight: int, spacing: float, skew: float) -> Font:
	var key := "sys|%s|%d|%s|%s" % [",".join(names), weight, spacing, skew]
	if _font_cache.has(key):
		return _font_cache[key]
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(names)
	sf.font_weight = weight
	sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	sf.hinting = TextServer.HINTING_LIGHT
	var f: Font = sf
	if spacing != 0.0 or skew != 0.0:
		var v := FontVariation.new()
		v.base_font = sf
		v.spacing_glyph = int(spacing)
		if skew != 0.0:
			v.variation_transform = Transform2D(Vector2(1, 0), Vector2(skew, 1), Vector2.ZERO)
		f = v
	_font_cache[key] = f
	return f

static func _mono(weight: int = 600, spacing: float = 0.0) -> Font:
	return _sys(["Noto Sans Mono", "DejaVu Sans Mono", "Roboto Mono", "Droid Sans Mono", "monospace"], weight, spacing, 0.0)

static func _skewed(f: Font, skew: float) -> Font:
	if skew == 0.0:
		return f
	var key := "skew|%d|%s" % [f.get_instance_id(), skew]
	if _font_cache.has(key):
		return _font_cache[key]
	var v := FontVariation.new()
	v.base_font = f
	v.variation_transform = Transform2D(Vector2(1, 0), Vector2(skew, 1), Vector2.ZERO)
	_font_cache[key] = v
	return v

# ---------------------------------------------------------------------------------------------------------------------
# Style boxes

static func _flat(bg: Color, border: Color, bw: int, radius: int, cm: Vector4, skew := 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(bw)
	s.border_color = border
	s.set_corner_radius_all(radius)
	s.corner_detail = 8 if radius > 0 else 1
	s.anti_aliasing = true
	s.content_margin_left = cm.x; s.content_margin_top = cm.y; s.content_margin_right = cm.z; s.content_margin_bottom = cm.w
	s.skew = Vector2(skew, 0.0)
	return s

static func _glow(s: StyleBoxFlat, color: Color, size: int, off := Vector2.ZERO) -> StyleBoxFlat:
	s.shadow_color = color
	s.shadow_size = size
	s.shadow_offset = off
	return s

static func _empty(cm := Vector4.ZERO) -> StyleBoxEmpty:
	var e := StyleBoxEmpty.new()
	e.content_margin_left = cm.x; e.content_margin_top = cm.y; e.content_margin_right = cm.z; e.content_margin_bottom = cm.w
	return e

# ---------------------------------------------------------------------------------------------------------------------
# Procedural icons (SDF rasterised into small ImageTextures)

static func _sd_box(p: Vector2, c: Vector2, half: Vector2, r: float) -> float:
	var q := (p - c).abs() - (half - Vector2(r, r))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r

static func _sd_seg(p: Vector2, a: Vector2, b: Vector2, w: float) -> float:
	var ab := b - a
	var h := clampf((p - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	return (p - a - ab * h).length() - w

static func _raster(size: int, sdf: Callable, fill: Color, border: Color, bw: float, extra: Callable = Callable()) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var d: float = sdf.call(p)
			var c := Color(0, 0, 0, 0)
			var cov_out := clampf(0.5 - d, 0.0, 1.0)
			var cov_in := clampf(0.5 - (d + bw), 0.0, 1.0)
			if cov_out > 0.0:
				c = c.blend(Color(border.r, border.g, border.b, border.a * cov_out))
			if cov_in > 0.0:
				c = c.blend(Color(fill.r, fill.g, fill.b, fill.a * cov_in))
			if extra.is_valid():
				c = extra.call(p, c)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

static func _icon_check(size: int, box: Color, border: Color, mark: Color, radius: float, checked: bool, bw: float) -> ImageTexture:
	var c := Vector2(size, size) * 0.5
	var half := Vector2(size, size) * 0.5 - Vector2(1.5, 1.5)
	var sdf := func(p: Vector2) -> float: return _sd_box(p, c, half, radius)
	var extra := Callable()
	if checked:
		var a := Vector2(size * 0.26, size * 0.52)
		var b := Vector2(size * 0.44, size * 0.70)
		var e := Vector2(size * 0.76, size * 0.32)
		var w := size * 0.08
		extra = func(p: Vector2, base: Color) -> Color:
			var d := minf(_sd_seg(p, a, b, w), _sd_seg(p, b, e, w))
			var cov := clampf(0.5 - d, 0.0, 1.0)
			return base.blend(Color(mark.r, mark.g, mark.b, mark.a * cov))
	return _raster(size, sdf, box, border, bw, extra)

static func _icon_radio(size: int, box: Color, border: Color, mark: Color, checked: bool, bw: float) -> ImageTexture:
	var c := Vector2(size, size) * 0.5
	var r := size * 0.5 - 1.5
	var sdf := func(p: Vector2) -> float: return (p - c).length() - r
	var extra := Callable()
	if checked:
		extra = func(p: Vector2, base: Color) -> Color:
			var d := (p - c).length() - size * 0.22
			var cov := clampf(0.5 - d, 0.0, 1.0)
			return base.blend(Color(mark.r, mark.g, mark.b, mark.a * cov))
	return _raster(size, sdf, box, border, bw, extra)

static func _icon_circle(size: int, fill: Color, border: Color, bw: float) -> ImageTexture:
	var c := Vector2(size, size) * 0.5
	var r := size * 0.5 - 1.0
	return _raster(size, func(p: Vector2) -> float: return (p - c).length() - r, fill, border, bw)

static func _icon_arrow(size: int, color: Color, up := false) -> ImageTexture:
	var a := Vector2(size * 0.2, size * 0.36)
	var b := Vector2(size * 0.5, size * 0.68)
	var e := Vector2(size * 0.8, size * 0.36)
	if up:
		a.y = size * 0.64; b.y = size * 0.32; e.y = size * 0.64
	var w := size * 0.09
	return _raster(size, func(p: Vector2) -> float: return minf(_sd_seg(p, a, b, w), _sd_seg(p, b, e, w)), color, color, 0.0)

# ---------------------------------------------------------------------------------------------------------------------
# Theme assembly

static func build(id: StringName) -> Theme:
	if not valid(id):
		id = DEFAULT
	var P := palette(id)
	var S := _spec(id)
	var t := Theme.new()
	var body: Font = S.body
	var heading: Font = _skewed(S.heading, S.heading_skew)
	var btn_font: Font = S.button
	var mono: Font = S.mono
	var R: int = S.radius
	var BW: int = S.border
	var SK: float = S.skew
	var accent: Color = P.accent
	var text: Color = P.text
	var cartoon := id == &"cartoon"
	var candy := id == &"candy"
	var border_col: Color = P.panel_border if not cartoon else P.panel_border
	var btn_border: Color = (accent if id == &"negatron" else (P.panel_border if (cartoon or candy) else accent.darkened(0.35)))
	var btn_text: Color = text if (cartoon or candy) else text
	var pill := 999 if candy else R

	t.default_font = body
	t.default_font_size = 18

	# ---- Labels
	t.set_font("font", "Label", body); t.set_font_size("font_size", "Label", 18)
	t.set_color("font_color", "Label", text); t.set_color("font_outline_color", "Label", P.outline)
	t.set_constant("outline_size", "Label", 0); t.set_constant("line_spacing", "Label", 3)
	t.set_stylebox("normal", "Label", _empty())
	for v in ["Title", "Heading", "Subtitle", "Info", "Dim", "Danger", "Success", "HudLabel", "HudScore", "HudBanner", "HudCross", "HudFeed", "Mono", "TeamJimmyLabel", "TeamNegatronLabel"]:
		t.set_type_variation(v, "Label")
	t.set_font("font", "Title", heading); t.set_font_size("font_size", "Title", S.title_size)
	t.set_color("font_color", "Title", accent if not cartoon else Color.WHITE)
	t.set_constant("outline_size", "Title", S.title_outline); t.set_color("font_outline_color", "Title", P.outline if not cartoon else P.panel_border)
	t.set_font("font", "Heading", heading); t.set_font_size("font_size", "Heading", 26); t.set_color("font_color", "Heading", accent if not cartoon else text)
	t.set_font("font", "Subtitle", body); t.set_font_size("font_size", "Subtitle", 18); t.set_color("font_color", "Subtitle", P.text_dim)
	t.set_font("font", "Info", btn_font); t.set_font_size("font_size", "Info", 18); t.set_color("font_color", "Info", P.warning if not cartoon else P.accent)
	t.set_font_size("font_size", "Dim", 16); t.set_color("font_color", "Dim", P.text_dim)
	t.set_color("font_color", "Danger", P.danger); t.set_font("font", "Danger", btn_font)
	t.set_color("font_color", "Success", P.success)
	t.set_color("font_color", "TeamJimmyLabel", P.team_jimmy); t.set_color("font_color", "TeamNegatronLabel", P.team_negatron)
	for v in ["HudLabel", "HudScore", "HudBanner", "HudCross", "HudFeed"]:
		t.set_color("font_outline_color", v, P.outline); t.set_constant("outline_size", v, S.hud_outline)
		t.set_color("font_color", v, Color.WHITE)
	t.set_font("font", "HudLabel", btn_font); t.set_font_size("font_size", "HudLabel", 17)
	t.set_font("font", "HudScore", heading); t.set_font_size("font_size", "HudScore", 28); t.set_color("font_color", "HudScore", Color.WHITE)
	t.set_font("font", "HudBanner", heading); t.set_font_size("font_size", "HudBanner", 46); t.set_color("font_color", "HudBanner", accent if not cartoon else P.accent2)
	t.set_constant("outline_size", "HudBanner", S.hud_outline + 3)
	t.set_font_size("font_size", "HudCross", 28)
	t.set_font("font", "HudFeed", btn_font); t.set_font_size("font_size", "HudFeed", 19)
	t.set_font("font", "Mono", mono); t.set_font_size("font_size", "Mono", 17)

	# ---- Buttons
	var cm := Vector4(22, 12, 22, 12)
	var b_normal := _flat(P.surface, btn_border, BW, pill, cm, SK)
	var b_hover := _flat(P.surface_hover, accent if not cartoon else P.panel_border, BW, pill, cm, SK)
	var b_pressed := _flat(P.surface_pressed, accent if not cartoon else P.panel_border, BW, pill, cm, SK)
	var b_disabled := _flat(P.surface_disabled, P.text_disabled.darkened(0.3) if not (cartoon or candy) else P.text_disabled, BW, pill, cm, SK)
	var focus_w: int = 3 if not cartoon else 5
	var b_focus := _flat(Color(0, 0, 0, 0), P.focus, focus_w, pill, cm, SK)
	_glow(b_focus, Color(P.focus, (0.2 if candy else 0.45) if not cartoon else 0.0), S.glow)
	if S.accent_stripe > 0:
		for s in [b_normal, b_hover, b_pressed, b_disabled]:
			s.border_width_left = S.accent_stripe + BW
		b_normal.border_color = accent.darkened(0.15)
	if S.shadow > 0:
		for s in [b_normal, b_hover]:
			_glow(s, Color(P.outline, 0.25 if candy else 1.0) if not cartoon else P.panel_border, S.shadow if not cartoon else 1, S.shadow_off * (0.5 if candy else 1.0))
		if cartoon:
			_glow(b_normal, P.panel_border, 1, Vector2(4, 4)); _glow(b_hover, P.panel_border, 1, Vector2(4, 4))
			_glow(b_pressed, P.panel_border, 1, Vector2(1, 1))
	t.set_stylebox("normal", "Button", b_normal); t.set_stylebox("hover", "Button", b_hover)
	t.set_stylebox("pressed", "Button", b_pressed); t.set_stylebox("disabled", "Button", b_disabled); t.set_stylebox("focus", "Button", b_focus)
	t.set_font("font", "Button", btn_font); t.set_font_size("font_size", "Button", 21)
	t.set_color("font_color", "Button", btn_text); t.set_color("font_hover_color", "Button", Color.WHITE if not (cartoon or candy) else text)
	t.set_color("font_pressed_color", "Button", P.text_on_accent); t.set_color("font_hover_pressed_color", "Button", P.text_on_accent)
	t.set_color("font_focus_color", "Button", Color.WHITE if not (cartoon or candy) else text); t.set_color("font_disabled_color", "Button", P.text_disabled)
	t.set_color("font_outline_color", "Button", P.outline); t.set_constant("outline_size", "Button", 0)
	t.set_constant("h_separation", "Button", 8); t.set_constant("icon_max_width", "Button", 32)
	for v in ["PrimaryButton", "SmallButton", "SlotButton", "ClassButton", "ClassButtonActive", "TeamJimmyButton", "TeamNegatronButton", "CycleButton", "ListButton"]:
		t.set_type_variation(v, "Button")
	# primary: accent filled
	var pcm := Vector4(26, 15, 26, 15)
	var p_normal := _flat(accent if not cartoon else P.accent2, accent.lightened(0.2) if not cartoon else P.panel_border, BW, pill, pcm, SK)
	var p_hover := _flat(accent.lightened(0.15) if not cartoon else P.accent2.lightened(0.2), accent.lightened(0.4) if not cartoon else P.panel_border, BW, pill, pcm, SK)
	var p_pressed := _flat(accent.darkened(0.2) if not cartoon else P.surface_pressed, accent if not cartoon else P.panel_border, BW, pill, pcm, SK)
	var p_focus := _flat(Color(0, 0, 0, 0), Color.WHITE if not cartoon else P.panel_border, focus_w, pill, pcm, SK)
	_glow(p_focus, Color(P.focus, (0.2 if candy else 0.45) if not cartoon else 0.0), S.glow)
	if S.shadow > 0:
		_glow(p_normal, Color(P.outline, 0.25 if candy else 1.0) if not cartoon else P.panel_border, S.shadow if not cartoon else 1, S.shadow_off * (0.5 if candy else 1.0))
		_glow(p_hover, Color(P.outline, 0.25 if candy else 1.0) if not cartoon else P.panel_border, S.shadow if not cartoon else 1, S.shadow_off * (0.5 if candy else 1.0))
	if cartoon:
		_glow(p_normal, P.panel_border, 1, Vector2(4, 4)); _glow(p_hover, P.panel_border, 1, Vector2(4, 4))
	t.set_stylebox("normal", "PrimaryButton", p_normal); t.set_stylebox("hover", "PrimaryButton", p_hover)
	t.set_stylebox("pressed", "PrimaryButton", p_pressed); t.set_stylebox("focus", "PrimaryButton", p_focus)
	t.set_stylebox("disabled", "PrimaryButton", b_disabled)
	t.set_font("font", "PrimaryButton", heading if id != &"lab" else btn_font); t.set_font_size("font_size", "PrimaryButton", 24)
	t.set_color("font_color", "PrimaryButton", P.text_on_accent); t.set_color("font_hover_color", "PrimaryButton", P.text_on_accent)
	t.set_color("font_focus_color", "PrimaryButton", P.text_on_accent); t.set_color("font_pressed_color", "PrimaryButton", Color.WHITE if not cartoon else text)
	# small / slot / class / list sizes
	var small_cm := Vector4(16, 8, 16, 8)
	for v in ["SmallButton", "ClassButton", "ClassButtonActive"]:
		t.set_stylebox("normal", v, _dup_cm(b_normal, small_cm)); t.set_stylebox("hover", v, _dup_cm(b_hover, small_cm))
		t.set_stylebox("pressed", v, _dup_cm(b_pressed, small_cm)); t.set_stylebox("disabled", v, _dup_cm(b_disabled, small_cm))
		t.set_stylebox("focus", v, _dup_cm(b_focus, small_cm)); t.set_font_size("font_size", v, 18)
	var ca := _dup_cm(b_normal, small_cm)
	ca.bg_color = Color(P.success, 0.22) if not cartoon else P.success.lightened(0.45)
	ca.border_color = P.success
	ca.set_border_width_all(BW if not cartoon else 4)
	if S.accent_stripe > 0: ca.border_width_left = S.accent_stripe + BW
	t.set_stylebox("normal", "ClassButtonActive", ca)
	t.set_color("font_color", "ClassButtonActive", P.success if not cartoon else text)
	var slot_cm := Vector4(18, 10, 18, 10)
	t.set_stylebox("normal", "SlotButton", _dup_cm(b_normal, slot_cm)); t.set_stylebox("hover", "SlotButton", _dup_cm(b_hover, slot_cm))
	t.set_stylebox("pressed", "SlotButton", _dup_cm(b_pressed, slot_cm)); t.set_stylebox("focus", "SlotButton", _dup_cm(b_focus, slot_cm))
	t.set_font_size("font_size", "SlotButton", 21)
	t.set_stylebox("normal", "CycleButton", _dup_cm(b_normal, slot_cm)); t.set_stylebox("hover", "CycleButton", _dup_cm(b_hover, slot_cm))
	t.set_stylebox("pressed", "CycleButton", _dup_cm(b_pressed, slot_cm)); t.set_stylebox("focus", "CycleButton", _dup_cm(b_focus, slot_cm))
	t.set_font_size("font_size", "CycleButton", 19)
	t.set_font_size("font_size", "ListButton", 20)
	# team buttons: team colour border + text
	for pair in [["TeamJimmyButton", P.team_jimmy], ["TeamNegatronButton", P.team_negatron]]:
		var v: String = pair[0]
		var tc: Color = pair[1]
		var tn := _dup_cm(b_normal, Vector4(26, 16, 26, 16)); tn.border_color = tc; tn.set_border_width_all(BW + 1)
		if S.accent_stripe > 0: tn.border_width_left = S.accent_stripe + BW
		if cartoon: tn.bg_color = tc.lightened(0.55); tn.border_color = P.panel_border; tn.set_border_width_all(4)
		var th := _dup_cm(b_hover, Vector4(26, 16, 26, 16)); th.border_color = tc.lightened(0.3)
		if cartoon: th.bg_color = tc.lightened(0.35); th.border_color = P.panel_border
		var tp := _dup_cm(b_pressed, Vector4(26, 16, 26, 16)); tp.bg_color = tc; tp.border_color = tc.lightened(0.3)
		var tf := _dup_cm(b_focus, Vector4(26, 16, 26, 16)); tf.border_color = tc.lightened(0.4) if not cartoon else P.panel_border
		_glow(tf, Color(tc, (0.25 if candy else 0.5) if not cartoon else 0.0), S.glow + 2)
		t.set_stylebox("normal", v, tn); t.set_stylebox("hover", v, th); t.set_stylebox("pressed", v, tp); t.set_stylebox("focus", v, tf)
		t.set_font("font", v, heading); t.set_font_size("font_size", v, 28)
		t.set_color("font_color", v, tc.lightened(0.25) if not cartoon else text); t.set_color("font_hover_color", v, tc.lightened(0.5) if not cartoon else text)
		t.set_color("font_focus_color", v, tc.lightened(0.5) if not cartoon else text); t.set_color("font_pressed_color", v, Color.WHITE if not cartoon else text)

	# ---- CheckBox / CheckButton
	var ck := 28
	t.set_icon("checked", "CheckBox", _icon_check(ck, P.field if not cartoon else P.field, accent if not cartoon else P.panel_border, accent if not cartoon else P.accent, 6 if not candy else 9, true, 2.0))
	t.set_icon("unchecked", "CheckBox", _icon_check(ck, P.field, P.text_dim if not cartoon else P.panel_border, accent, 6 if not candy else 9, false, 2.0))
	t.set_icon("checked_disabled", "CheckBox", _icon_check(ck, P.surface_disabled, P.text_disabled, P.text_disabled, 6, true, 2.0))
	t.set_icon("unchecked_disabled", "CheckBox", _icon_check(ck, P.surface_disabled, P.text_disabled, P.text_disabled, 6, false, 2.0))
	t.set_icon("radio_checked", "CheckBox", _icon_radio(ck, P.field, accent if not cartoon else P.panel_border, accent, true, 2.0))
	t.set_icon("radio_unchecked", "CheckBox", _icon_radio(ck, P.field, P.text_dim if not cartoon else P.panel_border, accent, false, 2.0))
	t.set_icon("radio_checked_disabled", "CheckBox", _icon_radio(ck, P.surface_disabled, P.text_disabled, P.text_disabled, true, 2.0))
	t.set_icon("radio_unchecked_disabled", "CheckBox", _icon_radio(ck, P.surface_disabled, P.text_disabled, P.text_disabled, false, 2.0))
	var cb_cm := Vector4(10, 10, 14, 10)
	var cb_focus := _flat(Color(0, 0, 0, 0), P.focus, 2, R, cb_cm)
	_glow(cb_focus, Color(P.focus, 0.4 if not cartoon else 0.0), S.glow / 2)
	t.set_stylebox("normal", "CheckBox", _empty(cb_cm)); t.set_stylebox("hover", "CheckBox", _flat(Color(accent, 0.1), Color(0, 0, 0, 0), 0, R, cb_cm))
	t.set_stylebox("pressed", "CheckBox", _empty(cb_cm)); t.set_stylebox("disabled", "CheckBox", _empty(cb_cm)); t.set_stylebox("focus", "CheckBox", cb_focus)
	t.set_stylebox("hover_pressed", "CheckBox", _flat(Color(accent, 0.1), Color(0, 0, 0, 0), 0, R, cb_cm))
	t.set_font("font", "CheckBox", btn_font); t.set_font_size("font_size", "CheckBox", 19)
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(cn, "CheckBox", text)
	t.set_color("font_disabled_color", "CheckBox", P.text_disabled)
	t.set_constant("h_separation", "CheckBox", 10); t.set_constant("check_v_offset", "CheckBox", 0)
	t.set_stylebox("normal", "CheckButton", _empty(cb_cm)); t.set_stylebox("hover", "CheckButton", _flat(Color(accent, 0.1), Color(0, 0, 0, 0), 0, R, cb_cm))
	t.set_stylebox("pressed", "CheckButton", _empty(cb_cm)); t.set_stylebox("disabled", "CheckButton", _empty(cb_cm)); t.set_stylebox("focus", "CheckButton", cb_focus)
	t.set_font("font", "CheckButton", btn_font); t.set_font_size("font_size", "CheckButton", 19)
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(cn, "CheckButton", text)
	t.set_icon("checked", "CheckButton", _icon_toggle(true, P, cartoon)); t.set_icon("unchecked", "CheckButton", _icon_toggle(false, P, cartoon))
	t.set_icon("checked_disabled", "CheckButton", _icon_toggle(true, P, cartoon)); t.set_icon("unchecked_disabled", "CheckButton", _icon_toggle(false, P, cartoon))

	# ---- OptionButton + PopupMenu
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(st, "OptionButton", t.get_stylebox(st, "Button"))
	t.set_font("font", "OptionButton", btn_font); t.set_font_size("font_size", "OptionButton", 19)
	for cn in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(cn, "OptionButton", text)
	t.set_color("font_pressed_color", "OptionButton", P.text_on_accent); t.set_color("font_hover_pressed_color", "OptionButton", P.text_on_accent)
	t.set_color("font_disabled_color", "OptionButton", P.text_disabled)
	t.set_icon("arrow", "OptionButton", _icon_arrow(20, accent if not cartoon else text))
	t.set_constant("arrow_margin", "OptionButton", 10); t.set_constant("modulate_arrow", "OptionButton", 0); t.set_constant("h_separation", "OptionButton", 8)
	var pm := _flat(P.panel.lightened(0.02) if not (cartoon or candy) else P.panel, border_col, BW if not cartoon else 4, R, Vector4(8, 8, 8, 8))
	pm.bg_color.a = 1.0
	_glow(pm, Color(P.outline, 0.5), 12, Vector2(0, 4))
	t.set_stylebox("panel", "PopupMenu", pm)
	t.set_stylebox("hover", "PopupMenu", _flat(accent if not cartoon else P.accent2, Color(0, 0, 0, 0), 0, maxi(R - 2, 0), Vector4(6, 4, 6, 4)))
	t.set_stylebox("separator", "PopupMenu", _line(Color(P.text_dim, 0.4)))
	t.set_stylebox("labeled_separator_left", "PopupMenu", _line(Color(P.text_dim, 0.4))); t.set_stylebox("labeled_separator_right", "PopupMenu", _line(Color(P.text_dim, 0.4)))
	t.set_font("font", "PopupMenu", btn_font); t.set_font_size("font_size", "PopupMenu", 19)
	t.set_color("font_color", "PopupMenu", text); t.set_color("font_hover_color", "PopupMenu", P.text_on_accent if not cartoon else text)
	t.set_color("font_disabled_color", "PopupMenu", P.text_disabled); t.set_color("font_accelerator_color", "PopupMenu", P.text_dim); t.set_color("font_separator_color", "PopupMenu", P.text_dim)
	t.set_constant("v_separation", "PopupMenu", 10); t.set_constant("item_start_padding", "PopupMenu", 14); t.set_constant("item_end_padding", "PopupMenu", 14)
	t.set_constant("h_separation", "PopupMenu", 8); t.set_constant("icon_max_width", "PopupMenu", 24)
	t.set_icon("checked", "PopupMenu", t.get_icon("checked", "CheckBox")); t.set_icon("unchecked", "PopupMenu", t.get_icon("unchecked", "CheckBox"))
	t.set_icon("radio_checked", "PopupMenu", t.get_icon("radio_checked", "CheckBox")); t.set_icon("radio_unchecked", "PopupMenu", t.get_icon("radio_unchecked", "CheckBox"))
	t.set_icon("checked_disabled", "PopupMenu", t.get_icon("checked_disabled", "CheckBox")); t.set_icon("unchecked_disabled", "PopupMenu", t.get_icon("unchecked_disabled", "CheckBox"))
	t.set_icon("radio_checked_disabled", "PopupMenu", t.get_icon("radio_checked_disabled", "CheckBox")); t.set_icon("radio_unchecked_disabled", "PopupMenu", t.get_icon("radio_unchecked_disabled", "CheckBox"))
	t.set_icon("submenu", "PopupMenu", _icon_arrow(20, accent)); t.set_icon("submenu_mirrored", "PopupMenu", _icon_arrow(20, accent))

	# ---- LineEdit / TextEdit
	var le_cm := Vector4(14, 10, 14, 10)
	var le_normal := _flat(P.field, P.text_dim.darkened(0.2) if not cartoon else P.panel_border, BW if not cartoon else 3, R if not candy else 14, le_cm)
	var le_focus := _flat(P.field, P.focus, 2 if not cartoon else 4, R if not candy else 14, le_cm)
	_glow(le_focus, Color(P.focus, 0.45 if not cartoon else 0.0), S.glow / 2)
	t.set_stylebox("normal", "LineEdit", le_normal); t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_stylebox("read_only", "LineEdit", _flat(P.surface_disabled, P.text_disabled, BW, R if not candy else 14, le_cm))
	t.set_font("font", "LineEdit", body); t.set_font_size("font_size", "LineEdit", 18)
	t.set_color("font_color", "LineEdit", text); t.set_color("font_selected_color", "LineEdit", P.text_on_accent); t.set_color("font_uneditable_color", "LineEdit", P.text_disabled)
	t.set_color("font_placeholder_color", "LineEdit", Color(P.text_dim, 0.7)); t.set_color("caret_color", "LineEdit", accent)
	t.set_color("selection_color", "LineEdit", Color(accent, 0.55)); t.set_color("clear_button_color", "LineEdit", P.text_dim)
	t.set_constant("minimum_character_width", "LineEdit", 6); t.set_constant("caret_width", "LineEdit", 2)
	t.set_stylebox("normal", "TextEdit", le_normal); t.set_stylebox("focus", "TextEdit", le_focus); t.set_stylebox("read_only", "TextEdit", t.get_stylebox("read_only", "LineEdit"))
	t.set_font("font", "TextEdit", body); t.set_font_size("font_size", "TextEdit", 18)
	t.set_color("font_color", "TextEdit", text); t.set_color("caret_color", "TextEdit", accent); t.set_color("selection_color", "TextEdit", Color(accent, 0.55))
	t.set_color("font_placeholder_color", "TextEdit", Color(P.text_dim, 0.7)); t.set_color("background_color", "TextEdit", P.field)

	# ---- Panels
	var panel := _flat(P.panel, border_col, BW if not cartoon else 4, R if not candy else 26, Vector4(28, 24, 28, 24))
	_glow(panel, Color(P.outline, 0.5 if not candy else 0.25) if not cartoon else P.panel_border, maxi(S.shadow, 10) if not cartoon else 1, S.shadow_off if not cartoon else Vector2(8, 8))
	if S.accent_stripe > 0:
		panel.border_width_top = 3; panel.border_color = accent
	t.set_stylebox("panel", "PanelContainer", _flat(P.panel, Color(0, 0, 0, 0), 0, R, Vector4(12, 12, 12, 12)))
	t.set_stylebox("panel", "Panel", _flat(P.panel, Color(0, 0, 0, 0), 0, R, Vector4(0, 0, 0, 0)))
	for v in ["MenuPanel", "SidePanel", "HudPanel", "ScoreboardPanel", "ListPanel"]:
		t.set_type_variation(v, "PanelContainer")
	t.set_stylebox("panel", "MenuPanel", panel)
	var side := _dup_cm(panel, Vector4(22, 18, 22, 18)); side.bg_color = Color(P.panel, P.panel.a * 0.85)
	if S.accent_stripe > 0: side.border_color = P.accent2; side.border_width_top = 3
	t.set_stylebox("panel", "SidePanel", side)
	var hudp := _flat(Color(P.overlay, 0.55), Color(accent, 0.6), 1 if not cartoon else 3, R, Vector4(12, 8, 12, 8))
	t.set_stylebox("panel", "HudPanel", hudp)
	var sbp := _flat(Color(P.panel, 0.95), border_col, BW if not cartoon else 4, R if not candy else 18, Vector4(28, 22, 28, 22))
	_glow(sbp, Color(P.outline, 0.6) if not cartoon else P.panel_border, 14 if not cartoon else 1, Vector2.ZERO if not cartoon else Vector2(6, 6))
	if S.accent_stripe > 0: sbp.border_width_top = 3; sbp.border_color = accent
	t.set_stylebox("panel", "ScoreboardPanel", sbp)
	t.set_stylebox("panel", "ListPanel", _flat(Color(P.field, 0.6), Color(P.text_dim, 0.35), 1, R, Vector4(10, 10, 10, 10)))
	t.set_stylebox("panel", "ScrollContainer", _empty())
	t.set_stylebox("panel", "TooltipPanel", _flat(P.panel, border_col, 1, R, Vector4(10, 6, 10, 6)))
	t.set_color("font_color", "TooltipLabel", text); t.set_font_size("font_size", "TooltipLabel", 16)

	# ---- Separators
	t.set_stylebox("separator", "HSeparator", _line(Color(accent if not cartoon else P.panel_border, 0.6), false, 2 if not cartoon else 4))
	t.set_stylebox("separator", "VSeparator", _line(Color(accent if not cartoon else P.panel_border, 0.6), true, 2 if not cartoon else 4))
	t.set_constant("separation", "HSeparator", 10); t.set_constant("separation", "VSeparator", 10)

	# ---- ProgressBar
	var bar_r := 3 if not candy else 8
	var bar_bg := _flat(P.bar_bg, Color(P.text_dim, 0.5) if not cartoon else P.panel_border, 1 if not cartoon else 3, bar_r, Vector4(2, 2, 2, 2))
	var bar_fill := _flat(accent, Color(0, 0, 0, 0), 0, maxi(bar_r - 1, 0), Vector4.ZERO)
	t.set_stylebox("background", "ProgressBar", bar_bg); t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_font("font", "ProgressBar", btn_font); t.set_font_size("font_size", "ProgressBar", 14)
	t.set_color("font_color", "ProgressBar", Color.WHITE if not (cartoon or candy) else text)
	t.set_color("font_outline_color", "ProgressBar", P.outline); t.set_constant("outline_size", "ProgressBar", 4 if not (cartoon or candy) else 3)
	for pair in [["HpBar", P.hp], ["FuelBar", P.fuel], ["UltBar", P.ult], ["UltBarReady", P.ult_ready], ["ImportBar", accent]]:
		var v: String = pair[0]
		t.set_type_variation(v, "ProgressBar")
		var f := _flat(pair[1], Color(0, 0, 0, 0), 0, maxi(bar_r - 1, 0), Vector4.ZERO)
		if v == "UltBarReady":
			_glow(f, Color(pair[1], 0.7), 6)
		t.set_stylebox("fill", v, f)
		t.set_stylebox("background", v, bar_bg if v != "ImportBar" else _dup_cm(bar_bg, Vector4(3, 3, 3, 3)))
	t.set_font_size("font_size", "ImportBar", 15)

	# ---- Sliders
	var track := _flat(P.bar_bg, Color(P.text_dim, 0.5) if not cartoon else P.panel_border, 1 if not cartoon else 3, 4, Vector4(0, 5, 0, 5))
	var track_fill := _flat(accent, Color(0, 0, 0, 0), 0, 4, Vector4(0, 5, 0, 5))
	var track_fill_hl := _flat(P.focus, Color(0, 0, 0, 0), 0, 4, Vector4(0, 5, 0, 5))
	for sl in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", sl, track); t.set_stylebox("grabber_area", sl, track_fill); t.set_stylebox("grabber_area_highlight", sl, track_fill_hl)
		t.set_icon("grabber", sl, _icon_circle(26, accent if not cartoon else P.accent2, P.outline if not cartoon else P.panel_border, 2.5))
		t.set_icon("grabber_highlight", sl, _icon_circle(28, P.focus if not cartoon else P.accent2, Color.WHITE if not cartoon else P.panel_border, 3.0))
		t.set_icon("grabber_disabled", sl, _icon_circle(26, P.surface_disabled, P.text_disabled, 2.0))
		t.set_icon("tick", sl, _icon_circle(6, Color(P.text_dim, 0.6), Color(0, 0, 0, 0), 0.0))
		t.set_constant("center_grabber", sl, 0); t.set_constant("grabber_offset", sl, 0)
	t.set_stylebox("focus", "HSlider", _empty())

	# ---- Scrollbars
	var sc_bg := _flat(Color(P.field, 0.6), Color(0, 0, 0, 0), 0, 4, Vector4(2, 2, 2, 2))
	var sc_gr := _flat(Color(accent, 0.6), Color(0, 0, 0, 0), 0, 4, Vector4(2, 2, 2, 2))
	var sc_hl := _flat(accent, Color(0, 0, 0, 0), 0, 4, Vector4(2, 2, 2, 2))
	for sb in ["HScrollBar", "VScrollBar"]:
		t.set_stylebox("scroll", sb, sc_bg); t.set_stylebox("scroll_focus", sb, sc_bg)
		t.set_stylebox("grabber", sb, sc_gr); t.set_stylebox("grabber_highlight", sb, sc_hl); t.set_stylebox("grabber_pressed", sb, sc_hl)
		t.set_icon("increment", sb, _blank()); t.set_icon("decrement", sb, _blank())
		t.set_icon("increment_highlight", sb, _blank()); t.set_icon("decrement_highlight", sb, _blank())
		t.set_icon("increment_pressed", sb, _blank()); t.set_icon("decrement_pressed", sb, _blank())
	sc_bg.content_margin_left = 6; sc_bg.content_margin_right = 6; sc_bg.content_margin_top = 6; sc_bg.content_margin_bottom = 6

	# ---- Lists / trees (file dialogs)
	var sel := _flat(Color(accent, 0.35) if not cartoon else P.accent2, Color(0, 0, 0, 0), 0, maxi(R - 2, 0), Vector4(4, 2, 4, 2))
	var selfocus := _flat(Color(accent, 0.45) if not cartoon else P.accent2, P.focus, 2, maxi(R - 2, 0), Vector4(4, 2, 4, 2))
	for lt in ["ItemList", "Tree"]:
		t.set_stylebox("panel", lt, _flat(P.field, Color(P.text_dim, 0.35), 1, R, Vector4(6, 6, 6, 6)))
		t.set_stylebox("focus", lt, _flat(Color(0, 0, 0, 0), P.focus, 2, R, Vector4(6, 6, 6, 6)))
		t.set_stylebox("selected", lt, sel); t.set_stylebox("selected_focus", lt, selfocus)
		t.set_stylebox("hovered", lt, _flat(Color(accent, 0.12), Color(0, 0, 0, 0), 0, maxi(R - 2, 0), Vector4(4, 2, 4, 2)))
		t.set_font("font", lt, body); t.set_font_size("font_size", lt, 17)
		t.set_color("font_color", lt, text); t.set_color("font_selected_color", lt, Color.WHITE if not cartoon else text); t.set_color("guide_color", lt, Color(P.text_dim, 0.3))
	t.set_stylebox("cursor", "Tree", selfocus); t.set_stylebox("cursor_unfocused", "Tree", sel)
	t.set_stylebox("button_pressed", "Tree", sel); t.set_stylebox("title_button_normal", "Tree", _flat(P.surface, Color(0, 0, 0, 0), 0, 0, Vector4(6, 4, 6, 4)))
	t.set_stylebox("title_button_hover", "Tree", _flat(P.surface_hover, Color(0, 0, 0, 0), 0, 0, Vector4(6, 4, 6, 4)))
	t.set_stylebox("title_button_pressed", "Tree", _flat(P.surface_pressed, Color(0, 0, 0, 0), 0, 0, Vector4(6, 4, 6, 4)))
	t.set_color("title_button_color", "Tree", text); t.set_color("drop_position_color", "Tree", accent)
	t.set_constant("v_separation", "Tree", 8); t.set_constant("v_separation", "ItemList", 8)
	t.set_stylebox("cursor", "ItemList", selfocus); t.set_stylebox("cursor_unfocused", "ItemList", sel)

	# ---- Windows / dialogs (FileDialog on desktop)
	var wp := _flat(P.panel, border_col, BW if not cartoon else 4, R, Vector4(16, 12, 16, 12)); wp.bg_color.a = 1.0
	_glow(wp, Color(P.outline, 0.6), 16, Vector2(0, 6))
	t.set_stylebox("embedded_border", "Window", _dup_cm(wp, Vector4(12, 46, 12, 12)))
	t.set_stylebox("embedded_unfocused_border", "Window", _dup_cm(wp, Vector4(12, 46, 12, 12)))
	t.set_font("title_font", "Window", heading); t.set_font_size("title_font_size", "Window", 20)
	t.set_color("title_color", "Window", accent if not cartoon else text); t.set_constant("title_height", "Window", 42)
	t.set_color("title_outline_modulate", "Window", P.outline); t.set_constant("title_outline_size", "Window", 0)
	t.set_icon("close", "Window", _icon_close(20, text)); t.set_icon("close_pressed", "Window", _icon_close(20, accent))
	t.set_constant("close_h_offset", "Window", 30); t.set_constant("close_v_offset", "Window", 30)
	for dt in ["AcceptDialog", "ConfirmationDialog", "FileDialog"]:
		t.set_stylebox("panel", dt, _dup_cm(wp, Vector4(16, 16, 16, 16)))
	t.set_color("file_icon_color", "FileDialog", text); t.set_color("folder_icon_color", "FileDialog", accent); t.set_color("file_disabled_color", "FileDialog", P.text_disabled)
	t.set_constant("buttons_separation", "AcceptDialog", 14)

	# ---- Tabs (future screens)
	var tab_sel := _flat(P.panel, border_col, BW, R, Vector4(16, 8, 16, 8)); tab_sel.bg_color.a = 1.0
	tab_sel.border_width_bottom = 0; tab_sel.corner_radius_bottom_left = 0; tab_sel.corner_radius_bottom_right = 0
	tab_sel.border_width_top = 3 if not cartoon else 4; tab_sel.border_color = accent if not cartoon else P.panel_border
	var tab_un := _flat(P.surface, Color(0, 0, 0, 0), 0, R, Vector4(16, 8, 16, 8)); tab_un.corner_radius_bottom_left = 0; tab_un.corner_radius_bottom_right = 0
	for tt in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_selected", tt, tab_sel); t.set_stylebox("tab_unselected", tt, tab_un); t.set_stylebox("tab_hovered", tt, _dup_cm(tab_un, Vector4(16, 8, 16, 8)))
		t.set_stylebox("tab_disabled", tt, tab_un); t.set_stylebox("tab_focus", tt, _flat(Color(0, 0, 0, 0), P.focus, 2, R, Vector4(16, 8, 16, 8)))
		t.set_font("font", tt, btn_font); t.set_font_size("font_size", tt, 19)
		t.set_color("font_selected_color", tt, accent if not cartoon else text); t.set_color("font_unselected_color", tt, P.text_dim); t.set_color("font_hovered_color", tt, text)
	t.set_stylebox("panel", "TabContainer", _dup_cm(panel, Vector4(16, 16, 16, 16)))

	# ---- Containers
	t.set_constant("separation", "VBoxContainer", 10); t.set_constant("separation", "HBoxContainer", 10)
	t.set_constant("margin_left", "MarginContainer", 16); t.set_constant("margin_right", "MarginContainer", 16)
	t.set_constant("margin_top", "MarginContainer", 16); t.set_constant("margin_bottom", "MarginContainer", 16)

	# ---- RichTextLabel
	t.set_stylebox("normal", "RichTextLabel", _empty()); t.set_stylebox("focus", "RichTextLabel", _empty())
	t.set_font("normal_font", "RichTextLabel", body); t.set_font_size("normal_font_size", "RichTextLabel", 18)
	t.set_font("bold_font", "RichTextLabel", btn_font); t.set_font_size("bold_font_size", "RichTextLabel", 18)
	t.set_font("mono_font", "RichTextLabel", mono); t.set_font_size("mono_font_size", "RichTextLabel", 17)
	t.set_color("default_color", "RichTextLabel", text); t.set_color("font_outline_color", "RichTextLabel", P.outline)
	return t

static func _dup_cm(s: StyleBoxFlat, cm: Vector4) -> StyleBoxFlat:
	var d := s.duplicate() as StyleBoxFlat
	d.content_margin_left = cm.x; d.content_margin_top = cm.y; d.content_margin_right = cm.z; d.content_margin_bottom = cm.w
	return d

static func _line(color: Color, vertical := false, thickness := 2) -> StyleBoxLine:
	var l := StyleBoxLine.new()
	l.color = color
	l.thickness = thickness
	l.vertical = vertical
	l.grow_begin = 0; l.grow_end = 0
	return l

static func _blank() -> ImageTexture:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

static func _icon_close(size: int, color: Color) -> ImageTexture:
	var a := Vector2(size * 0.25, size * 0.25); var b := Vector2(size * 0.75, size * 0.75)
	var c := Vector2(size * 0.75, size * 0.25); var d := Vector2(size * 0.25, size * 0.75)
	var w := size * 0.08
	return _raster(size, func(p: Vector2) -> float: return minf(_sd_seg(p, a, b, w), _sd_seg(p, c, d, w)), color, color, 0.0)

## Toggle switch icon (CheckButton): pill track + knob.
static func _icon_toggle(on: bool, P: Dictionary, cartoon: bool) -> ImageTexture:
	var w := 52; var h := 30
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track: Color = P.accent if on else P.field
	var border: Color = P.panel_border if cartoon else (P.accent if on else P.text_dim)
	var knob: Color = (P.text_on_accent if on else P.text_dim) if not cartoon else P.panel_border
	var kc := Vector2(w - h * 0.5, h * 0.5) if on else Vector2(h * 0.5, h * 0.5)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := _sd_box(p, Vector2(w, h) * 0.5, Vector2(w, h) * 0.5 - Vector2(1, 1), h * 0.5 - 1)
			var c := Color(0, 0, 0, 0)
			var cov_out := clampf(0.5 - d, 0.0, 1.0); var cov_in := clampf(0.5 - (d + 2.0), 0.0, 1.0)
			if cov_out > 0.0: c = c.blend(Color(border, border.a * cov_out))
			if cov_in > 0.0: c = c.blend(Color(track, track.a * cov_in))
			var kd := (p - kc).length() - (h * 0.5 - 5.0)
			var kcov := clampf(0.5 - kd, 0.0, 1.0)
			if kcov > 0.0: c = c.blend(Color(knob, knob.a * kcov))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
