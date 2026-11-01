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
