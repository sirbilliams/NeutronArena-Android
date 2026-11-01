class_name AnimFix
extends RefCounted
## Repairs two defects of the converted glb clips (found with tools/facing_probe.gd + tools/trackprobe2.gd):
## 1. every clip starts with a one-frame bind-pose key at t=0 (Jimmy's pelvis sits 60 units higher there, Negatron's root is turned
##    45 deg), so each loop flashed a wrong pose: the first key is dropped and the clip shifted back by one frame.
## 2. nummeyrun is authored facing -X while every other clip faces +X (Dummy01 rotation = Ry(180) * walk's): the root rotation
##    keys are turned back by 180 deg about the vertical axis, so Negatron no longer runs "backwards" (face towards the camera).
const FLIP_Y := Quaternion(0.0, 1.0, 0.0, 0.0)
const FLIP_CLIPS := ["nummeyrun"]

static func fix_player(ap: AnimationPlayer) -> void:
	for n in ap.get_animation_list():
		fix(ap.get_animation(n), n)
	_union_tracks(ap)

## Every clip keys the union of all bone tracks (missing ones = one rest-pose key), so a plain (non-deterministic) crossfade never leaves
## a bone at the previous clip's pose, and no blend pulls bones through the rest pose (AnimationPlayer.deterministic did, see Player).
static func _union_tracks(ap: AnimationPlayer) -> void:
	var root := ap.get_node_or_null(ap.root_node)
	if root == null:
		return
	var all := {}   # "path|type" -> [NodePath, type]
	for n in ap.get_animation_list():
		var a := ap.get_animation(n)
		for t in a.get_track_count():
			var ty := a.track_get_type(t)
			if ty == Animation.TYPE_POSITION_3D or ty == Animation.TYPE_ROTATION_3D or ty == Animation.TYPE_SCALE_3D:
				all["%s|%d" % [a.track_get_path(t), ty]] = [a.track_get_path(t), ty]
	for n in ap.get_animation_list():
		var a := ap.get_animation(n)
		if a.has_meta("union_done"):
			continue
		a.set_meta("union_done", true)
		var have := {}
		for t in a.get_track_count():
			have["%s|%d" % [a.track_get_path(t), a.track_get_type(t)]] = true
		for k in all:
			if have.has(k):
				continue
			var path: NodePath = all[k][0]
			var ty: int = all[k][1]
			var node := root.get_node_or_null(NodePath(path.get_concatenated_names()))
			var sk := node as Skeleton3D
			if sk == null or path.get_subname_count() == 0:
				continue
			var bi := sk.find_bone(path.get_concatenated_subnames())
			if bi < 0:
				continue
			var rest := sk.get_bone_rest(bi)
			var t := a.add_track(ty)
			a.track_set_path(t, path)
			match ty:
				Animation.TYPE_POSITION_3D: a.track_insert_key(t, 0.0, rest.origin)
				Animation.TYPE_ROTATION_3D: a.track_insert_key(t, 0.0, rest.basis.get_rotation_quaternion())
				_: a.track_insert_key(t, 0.0, rest.basis.get_scale())

static func fix(a: Animation, clip: String) -> void:
	if a.has_meta("anim_fixed"):
		return
	a.set_meta("anim_fixed", true)
	var shift := 1e9
	for t in a.get_track_count():
		if a.track_get_key_count(t) > 2 and absf(a.track_get_key_time(t, 0)) < 0.001:
			shift = minf(shift, a.track_get_key_time(t, 1))
	if shift > 1.0:
		shift = 0.0
	for t in a.get_track_count():
		var ty := a.track_get_type(t)
		if shift > 0.0 and a.track_get_key_count(t) > 2 and absf(a.track_get_key_time(t, 0)) < 0.001:
			a.track_remove_key(t, 0)
			for k in a.track_get_key_count(t):
				a.track_set_key_time(t, k, maxf(0.0, a.track_get_key_time(t, k) - shift))
		if ty == Animation.TYPE_ROTATION_3D and clip in FLIP_CLIPS and str(a.track_get_path(t)).ends_with(":Dummy01"):
			for k in a.track_get_key_count(t):
				a.track_set_key_value(t, k, FLIP_Y * (a.track_get_key_value(t, k) as Quaternion))
	if shift > 0.0:
		a.length = maxf(0.05, a.length - shift)
