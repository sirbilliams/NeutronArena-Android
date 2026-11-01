extends Node
## Native forward axis of a character glb from the skeleton in the model root frame (what MODEL_YAW rotates).
## forward = (char left) x up, left = L thigh - R thigh; also toe-minus-ankle and the knee bend direction.
func _ready() -> void:
	for rel in ["jimmy.glb", "nummey_villain.glb", "nummey.glb"]:
		var m := Assets.load_scene(rel) as Node3D
		add_child(m)
		var sk := _find(m)
		var ap := m.get_node("AnimationPlayer") as AnimationPlayer
		print("== ", rel, " anims=", ap.get_animation_list())
		for an in ["", "jimmyidle", "jimmywalk", "jimmyfullrun", "nummeystop", "nummeyrun", "nummeywalk", "jimmyfly", "jimmyjump", "jimmyfall", "jimmyscooter", "nummeyfly", "numflyair"]:
			if an != "":
				if not ap.has_animation(an): continue
				AnimFix.fix(ap.get_animation(an), an); ap.play(an); ap.seek(0.3, true); ap.advance(0.0)
			var xf: Transform3D = m.global_transform.affine_inverse() * sk.global_transform
			var P := func(n: String) -> Vector3: return xf * sk.get_bone_global_pose(sk.find_bone(n)).origin
			var left: Vector3 = P.call("Bip01 L Thigh") - P.call("Bip01 R Thigh")
			var fwd := left.cross(Vector3.UP)
			fwd.y = 0
			var toe: Vector3 = P.call("Bip01 L Toe0") - P.call("Bip01 L Foot")
			var knee: Vector3 = P.call("Bip01 L Calf") - 0.5 * (P.call("Bip01 L Thigh") + P.call("Bip01 L Foot"))
			var head: Vector3 = P.call("Bip01 Head")
			var hands: Vector3 = P.call("Bip01 R Hand") - P.call("Bip01 R Thigh")
			print("%-14s left=%s fwd(left x up)=%s toe=%s kneebend=%s head=%s" % [an if an != "" else "rest", left.snapped(Vector3.ONE*0.1), fwd.normalized().snapped(Vector3.ONE*0.01), toe.snapped(Vector3.ONE*0.1), knee.snapped(Vector3.ONE*0.1), head.snapped(Vector3.ONE*0.1)])
		m.queue_free()
	get_tree().quit()
func _find(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n
	for c in n.get_children():
		var r := _find(c)
		if r: return r
	return null
