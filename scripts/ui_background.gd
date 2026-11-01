class_name UiBackground
extends ColorRect
## Full-screen backdrop that follows the active UiTheme. `animated` = the title-screen procedural shader (cheap: a few
## sin/fract ops per fragment, Compatibility-renderer safe); otherwise a flat translucent overlay (in-game menus over the
## 3D world). Re-styles itself live when Config.theme_changed fires.
var animated := true
var _mat: ShaderMaterial
static var _shaders := {}

func _init(p_animated: bool = true) -> void:
	animated = p_animated
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # explicit offsets: a preset set in-tree keeps the current (empty) rect

func _ready() -> void:
	_restyle(UiTheme.current)
	Config.theme_changed.connect(_restyle)

func _restyle(id: StringName) -> void:
	if not animated:
		material = null
		color = UiTheme.col(&"overlay")
		return
	color = Color.WHITE
	var sh: Shader = _shaders.get(id)
	if sh == null:
		sh = Shader.new()
		sh.code = SHADERS.get(id, SHADERS[&"lab"])
		_shaders[id] = sh
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	var p := UiTheme.palette(id)
	_mat.set_shader_parameter("col_a", p.bg)
	_mat.set_shader_parameter("col_b", p.bg2)
	_mat.set_shader_parameter("accent", p.accent)
	_mat.set_shader_parameter("accent2", p.accent2)
	material = _mat

const HEAD := """shader_type canvas_item;
uniform vec4 col_a : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 col_b : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 accent : source_color = vec4(1.0);
uniform vec4 accent2 : source_color = vec4(1.0);
float hash1(float n) { return fract(sin(n) * 43758.5453); }
float hash2(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
"""

const SHADERS := {
	&"lab": HEAD + """
void fragment() {
	vec2 uv = UV;
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = uv * res;
	vec3 c = mix(col_b.rgb, col_a.rgb, uv.y);
	vec2 g1 = abs(fract(px / 32.0) - 0.5);
	float minor = 1.0 - smoothstep(0.0, 0.07, min(g1.x, g1.y));
	vec2 g2 = abs(fract(px / 160.0) - 0.5);
	float major = 1.0 - smoothstep(0.0, 0.02, min(g2.x, g2.y));
	c += accent.rgb * (minor * 0.06 + major * 0.14);
	float sweep = fract(TIME * 0.06);
	c += accent.rgb * exp(-abs(uv.y - sweep) * 22.0) * 0.10;
	float ring = abs(length((uv - vec2(0.5, 0.55)) * vec2(res.x / res.y, 1.0)) - 0.42 - 0.02 * sin(TIME * 0.7));
	c += accent2.rgb * (1.0 - smoothstep(0.0, 0.004, ring)) * 0.35;
	float v = smoothstep(1.25, 0.25, length((uv - 0.5) * vec2(1.2, 1.0)));
	c *= mix(0.45, 1.0, v);
	COLOR = vec4(c, 1.0);
}
""",
	&"negatron": HEAD + """
void fragment() {
	vec2 uv = UV;
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float t = TIME;
	float row = floor(uv.y * 44.0);
	float seed = floor(t * 7.0);
	float g = step(0.955, hash1(row * 1.7 + seed * 13.1));
	float shift = (hash1(row * 3.1 + seed) - 0.5) * 0.12 * g;
	vec2 suv = vec2(uv.x + shift, uv.y);
	vec3 c = mix(col_a.rgb, col_b.rgb, pow(suv.y, 1.6));
	float stripe = step(0.55, fract((suv.x - suv.y * 0.9) * 7.0 + t * 0.04));
	c = mix(c, c * 1.5 + accent.rgb * 0.06, stripe);
	c *= 0.86 + 0.14 * sin(uv.y * res.y * 3.14159 * 0.5);
	c += accent.rgb * g * 0.28 * step(0.5, fract(suv.x * 3.0 + seed));
	c += accent2.rgb * exp(-length((uv - vec2(0.85, 0.15)) * vec2(res.x / res.y, 1.0)) * 2.2) * 0.25;
	c += accent.rgb * pow(1.0 - abs(uv.x - 0.5) * 2.0, 6.0) * pow(uv.y, 2.0) * 0.35;
	float v = smoothstep(1.3, 0.3, length(uv - 0.5));
	c *= mix(0.5, 1.0, v);
	COLOR = vec4(c, 1.0);
}
""",
	&"candy": HEAD + """
void fragment() {
	vec2 uv = UV;
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float asp = res.x / res.y;
	vec2 p = vec2(uv.x * asp, uv.y);
	float t = TIME;
	vec3 c = mix(col_a.rgb, col_b.rgb, uv.y * 0.75 + uv.x * 0.25);
	float stripe = smoothstep(0.48, 0.52, abs(fract((p.x + p.y) * 2.5 + t * 0.02) - 0.5));
	c = mix(c, c * 1.04, stripe);
	for (int i = 0; i < 8; i++) {
		float fi = float(i);
		float spd = 0.025 + 0.012 * hash1(fi * 7.3);
		vec2 ctr = vec2(0.12 + 0.24 * fi * 0.95 + 0.07 * sin(t * 0.35 + fi * 1.7), 1.15 - fract(fi * 0.37 + t * spd) * 1.3);
		ctr.x = mod(ctr.x, asp + 0.2) - 0.1;
		float r = 0.06 + 0.06 * hash1(fi * 3.1);
		float d = length(p - ctr);
		float ring = smoothstep(r, r - 0.01, d) - smoothstep(r - 0.016, r - 0.03, d);
		float body = smoothstep(r, r - 0.01, d) * 0.18;
		vec3 bc = mix(accent.rgb, accent2.rgb, hash1(fi * 5.7));
		c = mix(c, bc, ring * 0.65 + body);
		float hl = smoothstep(r * 0.32, 0.0, length(p - ctr + vec2(r * 0.38, r * 0.38)));
		c += vec3(1.0) * hl * 0.55 * smoothstep(r, r - 0.01, d);
	}
	COLOR = vec4(c, 1.0);
}
""",
	&"yokian": HEAD + """
void fragment() {
	vec2 uv = UV;
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float t = TIME;
	vec3 c = mix(col_b.rgb, col_a.rgb, uv.y);
	vec2 p = vec2(uv.x * res.x / res.y, uv.y);
	float n1 = exp(-pow(length(p - vec2(0.55 + 0.06 * sin(t * 0.11), 0.35 + 0.04 * cos(t * 0.09))), 2.0) * 5.0);
	float n2 = exp(-pow(length(p - vec2(1.3 + 0.05 * cos(t * 0.13), 0.75)), 2.0) * 6.0);
	float n3 = exp(-pow(length(p - vec2(0.2, 0.9)), 2.0) * 9.0);
	c += accent2.rgb * n1 * 0.5 + accent.rgb * n2 * 0.22 + accent2.rgb * n3 * 0.3;
	vec2 sp = uv * vec2(150.0, 84.0) + vec2(t * 0.25, 0.0);
	vec2 cell = floor(sp);
	vec2 f = fract(sp) - 0.5;
	float h = hash2(cell);
	vec2 off = (vec2(hash2(cell + 1.0), hash2(cell + 2.0)) - 0.5) * 0.6;
	float star = step(0.93, h) * smoothstep(0.22, 0.0, length(f - off));
	star *= 0.55 + 0.45 * sin(t * 2.0 + h * 60.0);
	c += vec3(1.0) * star;
	vec2 sp2 = uv * vec2(60.0, 34.0) + vec2(t * 0.6, 0.0);
	vec2 cell2 = floor(sp2);
	float h2 = hash2(cell2 + 9.0);
	float big = step(0.985, h2) * smoothstep(0.1, 0.0, length(fract(sp2) - 0.5));
	c += mix(vec3(1.0), accent.rgb, 0.5) * big * (0.7 + 0.3 * sin(t * 3.0 + h2 * 40.0));
	float ring = abs(length((uv - vec2(0.78, 0.3)) * vec2(res.x / res.y, 1.0)) - 0.3);
	c += accent.rgb * (1.0 - smoothstep(0.0, 0.0035, ring)) * 0.4;
	COLOR = vec4(c, 1.0);
}
""",
	&"cartoon": HEAD + """
void fragment() {
	vec2 uv = UV;
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float t = TIME;
	vec2 px = uv * res;
	vec3 c = mix(col_a.rgb, col_b.rgb, uv.y);
	vec2 d = (uv - vec2(0.5, 0.45)) * vec2(res.x / res.y, 1.0);
	float ang = atan(d.y, d.x);
	float rays = step(0.5, fract(ang / 6.28318 * 16.0 + t * 0.02));
	c = mix(c, c * 1.16, rays * smoothstep(0.08, 0.7, length(d)));
	vec2 hp = fract(px / 24.0) - 0.5;
	float dotr = 0.08 + 0.26 * uv.y;
	float dots = smoothstep(dotr, dotr - 0.08, length(hp));
	c = mix(c, accent2.rgb * 0.9 + col_b.rgb * 0.1, dots * 0.5);
	vec2 cp = vec2(uv.x * res.x / res.y - fract(t * 0.03) * 2.6 + 0.4, uv.y);
	float cloud = smoothstep(0.22, 0.2, length((cp - vec2(0.9, 0.78)) * vec2(1.0, 2.2)))
		+ smoothstep(0.17, 0.15, length((cp - vec2(0.72, 0.74)) * vec2(1.0, 2.0)))
		+ smoothstep(0.15, 0.13, length((cp - vec2(1.08, 0.74)) * vec2(1.0, 2.0)));
	c = mix(c, vec3(1.0), clamp(cloud, 0.0, 1.0) * 0.85);
	COLOR = vec4(c, 1.0);
}
""",
}
