extends Node
func _ready() -> void:
	for rel in ["nummey.glb", "jimmy.glb"]:
		var o := Assets.load_scene(rel)
		var ap := o.get_node("AnimationPlayer") as AnimationPlayer
		for an in ["nummeywalk", "nummeyrun", "jimmywalk", "jimmyfullrun", "jimmyidle"]:
			if not ap.has_animation(an): continue
			var a := ap.get_animation(an)
			print("== ", an, " len ", a.length, " tracks ", a.get_track_count())
			for t in a.get_track_count():
				var p := str(a.track_get_path(t))
				if a.track_get_type(t) == 1 and (p.ends_with("Dummy01") or p.ends_with("Bip01") or "Pelvis" in p or "__Root" in p):
					var s := p + ": "
					var n := a.track_get_key_count(t)
					for k in range(0, n, max(1, n / 10)):
						s += " %.2f:%s" % [a.track_get_key_time(t, k), (a.track_get_key_value(t, k) as Vector3).snapped(Vector3.ONE * 0.1)]
					print(s)
				if a.track_get_type(t) == 2 and (p.ends_with("Dummy01") or p.ends_with("Bip01") or "__Root" in p):
					print(p, " rot first/last ", a.track_get_key_value(t, 1), a.track_get_key_value(t, a.track_get_key_count(t) - 1))
	get_tree().quit()
