extends Node
## Every clip of both characters must face +X after AnimFix, also when a clip arrives turned around (simulated: jimmyfullrun's top
## bone pre-rotated 180 deg, the way the Thor's import showed Jimmy running face-first).
func _ready() -> void:
	var ok := true
	for rel in ["jimmy.glb", "nummey_villain.glb"]:
		var m := Assets.load_scene(rel) as Node3D
		var ap := m.get_node("AnimationPlayer") as AnimationPlayer
		var sk := AnimFix._find_skeleton(m)
		if rel == "jimmy.glb":
			var a := ap.get_animation("jimmyfullrun")
			var top := AnimFix._top_animated_bone(sk, a)
			for ti in a.get_track_count():
				if a.track_get_type(ti) == Animation.TYPE_ROTATION_3D and a.track_get_path(ti).get_concatenated_subnames() == sk.get_bone_name(top):
					var up_sk := Vector3.UP
					var p := sk.get_bone_parent(top)
					var pr := sk.get_bone_global_rest(p).basis.orthonormalized() if p >= 0 else Basis()
					var conj := (pr.inverse() * Basis(up_sk, PI) * pr).get_rotation_quaternion()
					for k in a.track_get_key_count(ti):
						a.track_set_key_value(ti, k, conj * (a.track_get_key_value(ti, k) as Quaternion))
		AnimFix.fix_player(ap)
		for clip in ap.get_animation_list():
			var a := ap.get_animation(clip)
			var l := AnimFix._bone_global(sk, a, sk.find_bone("Bip01 L Thigh"), a.length * 0.5).origin
			var r := AnimFix._bone_global(sk, a, sk.find_bone("Bip01 R Thigh"), a.length * 0.5).origin
			var f := (l - r).cross(Vector3.UP); f.y = 0
			var good := f.length() < 1e-4 or f.normalized().x > -0.5
			print("%-18s %-16s fwd=%s %s" % [rel, clip, f.normalized().snapped(Vector3.ONE * 0.01), "ok" if good else "BACKWARDS"])
			ok = ok and good
		m.free()
	print("FACING TEST ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
