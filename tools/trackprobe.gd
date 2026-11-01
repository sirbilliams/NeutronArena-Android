extends Node
func _ready() -> void:
	var m := Assets.load_scene("jimmy.glb")
	add_child(m)
	var ap := m.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var sk := m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var b := sk.find_bone("Bip01 R Toe0")
	for an in ["jimmyfullrun", "jimmywalk"]:
		ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
		ap.play(an, 0.0)
		var out := []
		for i in 40:
			ap.advance(0.0333)
			out.append(snappedf(sk.get_bone_global_pose(b).origin.y * Config.WORLD_SCALE * 100, 0.1))
		print(an, " toeY ", out)
		var a := ap.get_animation(an)
		var s := []
		for i in 14:
			var t := a.length * i / 14.0
			ap.seek(t, true)
			s.append(snappedf(sk.get_bone_global_pose(b).origin.y * Config.WORLD_SCALE * 100, 0.1))
		print(an, " seek ", s)
	get_tree().quit()
