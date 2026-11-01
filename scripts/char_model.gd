class_name CharModel
extends RefCounted
## Builds the 3D model of a roster character (scripts/characters.gd) from the glbs imported on the device.
## Result: Node3D "model" with an "AnimationPlayer" whose clips are named "<base>_<role>" (carl_run ...), and meta
##   roles {idle, walk, run, jump, fall, fly -> clip name or ""}, palm_bone (StringName, "" = none), palm_off (Vector3, raw units:
##   bone space for skinned characters, model space for Libby), k (size factor on top of Config.WORLD_SCALE), skinned (bool).
## Skinned N2 characters (Carl, Cindy, Sheen) use their own clips where the game has them and Jimmy's clips for the rest (retargeted: tracks of
## __Root / Bip01 / Dummy01 dropped, rotations only - see research REPORT item 4). Libby has no skeleton: three vertex-animated meshes, one visible per clip.
## Evil clones get red eyes: the eye region of a copy of the skin texture is recoloured (tools/redeye.py rule, ellipses per atlas).
const DROP_BONES := ["__Root", "Bip01", "Dummy01"]
const JIMMY_CLIPS := {"idle": "jimmyidle", "walk": "jimmywalk", "run": "jimmyfullrun", "jump": "jimmyjump", "fall": "jimmyfall", "fly": "jimmyfly", "scooter": "jimmyscooter", "scooterstop": "jimmyscooterstop"}
## own clips of the N2 characters (role -> clip in their glb)
const OWN := {
	&"carl": {"walk": "carlwalk", "run": "carlrun", "idle": "carlstop"},
	&"cindy": {"walk": "cindywalk", "idle": "cindyidle"},
	&"sheen": {"idle": "sheenidle"},
}
## Libby: role -> [glb, node name inside it]
const LIBBY := {"idle": ["ase/n1/libystop.glb", "libystop"], "walk": ["ase/n1/libywalk.glb", "libywalk"], "run": ["ase/n1/libyrun.glb", "libyrun"], "wave": ["ase/n1/libywave.glb", "libywave"]}
const LIBBY_YAW := -PI / 2.0     # Libby natively faces -Z (ASE export), the rig expects +X
const LIBBY_WAVE_DY := -64.45   # libywave is authored with its origin 64 units lower than the other Libby poses
## model size factor per base (scale = WORLD_SCALE * k): measured heights, see tools/charcal.gd
const K := {&"jimmy": 1.0, &"negatron": 1.0, &"carl": 1.05, &"sheen": 1.1, &"cindy": 0.95, &"libby": 1.0}   # heights at k=1: carl 1.30, sheen 1.19, cindy 1.52, libby 1.42 (Jimmy 1.40)
## right palm centre: bone space (skinned) / model space (Libby), raw units, measured with tools/charcal.gd
const PALM := {
	&"carl": Vector3(18.17, 11.62, -0.59), &"sheen": Vector3(9.29, 2.74, -1.22), &"cindy": Vector3(10.76, 2.79, -1.10),
	&"libby": Vector3(15.0, 8.0, 19.0),   # model space after the yaw fix (forward +X, up +Y, right +Z): right-arm tip of the stop pose, pushed forward
}
## eye ellipses (cx, cy, rx, ry in texture pixels of the 256x256 atlas) and whether pupils stay dark
const EYES := {
	&"carl": {"ell": [[194, 75, 6, 7], [216, 75, 6, 7]], "pupil": false},
	&"cindy": {"ell": [[31, 39, 16, 13], [68, 39, 16, 13]], "pupil": true},
	&"sheen": {"ell": [[52, 47, 15, 14], [91, 47, 15, 14]], "pupil": true},
	&"libby": {"ell": [[86, 185, 18, 11]], "pupil": true},
}
static var _eye_cache := {}   # source texture instance id -> recoloured ImageTexture

## Returns null when the character's art is not on this device.
static func build(id: StringName) -> Node3D:
	var base := Characters.base_of(id)
	if not Characters.available(id):
		return null
	var m: Node3D
	match base:
		&"libby":
			m = _build_libby()
		&"carl", &"cindy", &"sheen":
			m = _build_skinned(base)
		_:
			return null   # Jimmy / Negatron keep their own path in Player._build_model
	if m == null:
		return null
	m.set_meta("k", K.get(base, 1.0))
	m.set_meta("palm_off", PALM.get(base, Vector3.ZERO))
	if Characters.is_evil(id):
		_redden_model(m, base)
	return m

## Model for the select screen: any roster character (Jimmy / Negatron included) with its idle clip. {model, idle, k} or {} when the art is missing.
static func build_display(id: StringName) -> Dictionary:
	if not Characters.available(id):
		return {}
	var base := Characters.base_of(id)
	var m: Node3D
	var idle := ""
	if base == &"jimmy" or base == &"negatron":
		m = Assets.load_scene("jimmy.glb" if base == &"jimmy" else "nummey_villain.glb") as Node3D
		var ap := m.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if base == &"negatron":
			var other := Assets.load_scene("nummey.glb")
			var oap := other.get_node_or_null("AnimationPlayer") as AnimationPlayer
			var lib := ap.get_animation_library("")
			if oap and not lib.has_animation("nummeystop"):
				lib.add_animation("nummeystop", oap.get_animation("nummeystop").duplicate())
			other.free()
		AnimFix.fix_player(ap)
		idle = "jimmyidle" if base == &"jimmy" else "nummeystop"
		for n in ap.get_animation_list():
			ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	else:
		m = build(id)
		if m == null:
			return {}
		idle = (m.get_meta("roles") as Dictionary).get("idle", "")
	return {"model": m, "idle": idle, "k": K.get(base, 1.0)}

# ---------------------------------------------------------------- skinned (Granny) characters
static func _build_skinned(base: StringName) -> Node3D:
	var m := Assets.load_scene("%s.glb" % base) as Node3D
	var ap := m.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var sks := m.find_children("*", "Skeleton3D", true, false)
	if ap == null or sks.is_empty():
		return null
	var sk := sks[0] as Skeleton3D
	var old := ap.get_animation_library("")
	var lib := AnimationLibrary.new()   # fresh library: the scene's own one is shared with the asset cache
	var roles := {}
	var own: Dictionary = OWN.get(base, {})
	for role in own:
		if old.has_animation(own[role]):
			var a := old.get_animation(own[role])
			AnimFix.fix(a, own[role])
			lib.add_animation("%s_%s" % [base, role], a.duplicate())
			roles[role] = "%s_%s" % [base, role]
	var jm := Assets.load_scene("jimmy.glb")
	var jap := jm.get_node_or_null("AnimationPlayer") as AnimationPlayer
	for role in JIMMY_CLIPS:
		if roles.has(role) or jap == null or not jap.has_animation(JIMMY_CLIPS[role]):
			continue
		var src := jap.get_animation(JIMMY_CLIPS[role])
		AnimFix.fix(src, JIMMY_CLIPS[role])
		var cname := "%s_%s" % [base, role]
		lib.add_animation(cname, retarget(src, sk))
		roles[role] = cname
	jm.free()
	ap.remove_animation_library("")
	ap.add_animation_library("", lib)
	for n in lib.get_animation_list():
		lib.get_animation(n).set_meta("anim_fixed", true)
	for n in lib.get_animation_list():
		_ensure_rot_track(lib.get_animation(n), sk, "Bip01 Pelvis")   # facing fix turns the topmost keyed bone: it must be the pelvis, not the spine
	AnimFix.face_exact(ap)
	AnimFix._union_tracks(ap)
	for n in lib.get_animation_list():
		lib.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	if roles.has("jump"):
		lib.get_animation(roles.jump).loop_mode = Animation.LOOP_NONE
	for r in JIMMY_CLIPS:
		if not roles.has(r):
			roles[r] = ""
	m.set_meta("roles", roles)
	m.set_meta("palm_bone", &"Bip01 R Hand")
	m.set_meta("skinned", true)
	return m

static func _ensure_rot_track(a: Animation, sk: Skeleton3D, bone: String) -> void:
	var bi := sk.find_bone(bone)
	if bi < 0:
		return
	for t in a.get_track_count():
		if a.track_get_type(t) == Animation.TYPE_ROTATION_3D and String(a.track_get_path(t).get_concatenated_subnames()) == bone:
			return
	var t := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(t, NodePath("Skeleton3D:" + bone))
	a.track_insert_key(t, 0.0, sk.get_bone_rest(bi).basis.get_rotation_quaternion())

## Copy of a Jimmy clip for another Biped skeleton: rotation tracks only, minus the root bones (their rest differs per model).
static func retarget(src: Animation, sk: Skeleton3D) -> Animation:
	var a := src.duplicate() as Animation
	for mk in a.get_meta_list():   # duplicate() keeps AnimFix's done-markers (union_done ...): this copy is a new clip for another skeleton
		a.remove_meta(mk)
	for t in range(a.get_track_count() - 1, -1, -1):
		var path := a.track_get_path(t)
		var bone := String(path.get_concatenated_subnames())
		var keep := a.track_get_type(t) == Animation.TYPE_ROTATION_3D and bone != "" and not DROP_BONES.has(bone) and sk.find_bone(bone) >= 0 \
			and a.track_get_key_count(t) > 1   # one-key tracks are rest-pose filler (AnimFix._union_tracks on Jimmy's shared clips), the target keeps its own rest
		if not keep:
			a.remove_track(t)
	return a

# ---------------------------------------------------------------- Libby (vertex animated)
static func _build_libby() -> Node3D:
	var root := Node3D.new()
	root.name = "LibbyModel"
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	var lib := AnimationLibrary.new()
	var roles := {}
	var variants := {}   # clip name -> node name
	for role in LIBBY:
		var rel: String = LIBBY[role][0]
		var stem: String = LIBBY[role][1]
		var sc := Assets.try_scene(rel) as Node3D
		if sc == null:
			continue
		var node := sc.get_node_or_null(stem) as Node3D
		var sap := sc.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if node == null or sap == null or sap.get_animation_list().is_empty():
			sc.free()
			continue
		sc.remove_child(node)
		root.add_child(node)
		node.visible = role == "idle"
		node.rotation.y = LIBBY_YAW
		if role == "wave":
			node.position.y = LIBBY_WAVE_DY
		var clip := "libby_%s" % role
		lib.add_animation(clip, sap.get_animation(sap.get_animation_list()[0]).duplicate())
		lib.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		variants[clip] = node
		roles[role] = clip
		sc.free()
	ap.add_animation_library("", lib)
	ap.animation_started.connect(func(clip: StringName):
		for c in variants:
			(variants[c] as Node3D).visible = c == str(clip))
	for r in JIMMY_CLIPS:
		if not roles.has(r):
			roles[r] = ""   # no jump / fall / fly clips: Player holds a run frame in the air
	m_set(root, roles)
	return root

static func m_set(root: Node3D, roles: Dictionary) -> void:
	root.set_meta("roles", roles)
	root.set_meta("palm_bone", &"")
	root.set_meta("skinned", false)

# ---------------------------------------------------------------- red eyes
static func _redden_model(m: Node3D, base: StringName) -> void:
	var spec: Dictionary = EYES.get(base, {})
	if spec.is_empty():
		return
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as BaseMaterial3D
			if mat == null or mat.albedo_texture == null:
				continue
			var key := mat.albedo_texture.get_instance_id()
			if not _eye_cache.has(key):
				var img := mat.albedo_texture.get_image()
				if img == null:
					continue
				img = img.duplicate()
				if img.is_compressed():
					img.decompress()
				img.convert(Image.FORMAT_RGBA8)
				redden_image(img, spec.ell, spec.pupil)
				_eye_cache[key] = ImageTexture.create_from_image(img)
			var nm := mat.duplicate() as BaseMaterial3D
			nm.albedo_texture = _eye_cache[key]
			(mi as MeshInstance3D).set_surface_override_material(s, nm)

## Iris / dark eye pixels inside the ellipses turn red (brightness kept), near-white sclera gets a bloodshot tint, pupils stay dark if `keep_pupil`.
static func redden_image(img: Image, ells: Array, keep_pupil: bool) -> void:
	for e in ells:
		var cx: int = e[0]; var cy: int = e[1]; var rx: int = e[2]; var ry: int = e[3]
		for y in range(maxi(cy - ry, 0), mini(cy + ry + 1, img.get_height())):
			for x in range(maxi(cx - rx, 0), mini(cx + rx + 1, img.get_width())):
				var dx := float(x - cx) / float(rx); var dy := float(y - cy) / float(ry)
				if dx * dx + dy * dy > 1.0:
					continue
				var c := img.get_pixel(x, y)
				var mx := maxf(c.r, maxf(c.g, c.b)); var mn := minf(c.r, minf(c.g, c.b))
				var lum := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
				if mn > 0.6 and mx - mn < 0.22:
					img.set_pixel(x, y, Color(c.r, c.g * 0.55, c.b * 0.55, c.a))   # sclera
				elif keep_pupil and lum < 0.16:
					continue
				elif lum < 0.55:
					img.set_pixel(x, y, Color(clampf(0.45 + lum * 1.3, 0.0, 1.0), lum * 0.18, lum * 0.12, c.a))
