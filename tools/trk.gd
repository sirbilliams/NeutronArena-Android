extends Node
func _ready() -> void:
	var m := Assets.load_scene("jimmy.glb")
	add_child(m)
	var ap := m.get_node("AnimationPlayer") as AnimationPlayer
	for cn in ["jimmyidle","jimmywalk","jimmyfullrun"]:
		var a := ap.get_animation(cn)
		var raw := a.duplicate()
		print("== ", cn, " len ", a.length, " tracks ", a.get_track_count())
		for t in a.get_track_count():
			var path := str(a.track_get_path(t))
			if path.ends_with("Head") or path.ends_with("Neck") or path.ends_with("Spine") or path.ends_with("Spine1") or path.ends_with("Pelvis") or path.ends_with("Dummy01") or path.ends_with("Bip01"):
				var ks := []
				for k in mini(a.track_get_key_count(t), 4): ks.append("%.3f" % a.track_get_key_time(t, k))
				print(path.get_slice(":", 1), " type ", a.track_get_type(t), " keys ", a.track_get_key_count(t), " first ", ks, " last ", "%.3f" % a.track_get_key_time(t, a.track_get_key_count(t)-1))
	get_tree().quit()
