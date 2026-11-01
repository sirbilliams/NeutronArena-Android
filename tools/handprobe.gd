extends Node
## Hand bone frame: where the hand mesh (vertices skinned mainly to Bip01 R Hand) sits in the bone's local space (raw units).
func _ready() -> void:
	for rel in ["jimmy.glb", "nummey_villain.glb"]:
		var m := Assets.load_scene(rel) as Node3D
		add_child(m)
		var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
		var hb := sk.find_bone("Bip01 R Hand")
		print("== ", rel, " hand bone ", hb, " parent ", sk.get_bone_name(sk.get_bone_parent(hb)))
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var mesh := (mi as MeshInstance3D).mesh as ArrayMesh
			var skin: Skin = (mi as MeshInstance3D).skin
			if skin == null: continue
			var bi := -1
			for i in skin.get_bind_count():
				var nm := skin.get_bind_name(i)
				if nm == "" : nm = sk.get_bone_name(skin.get_bind_bone(i))
				if nm == "Bip01 R Hand": bi = i
			if bi < 0: continue
			var pts := PackedVector3Array()
			for s in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(s)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var b: PackedInt32Array = arr[Mesh.ARRAY_BONES]
				var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
				var n := b.size() / v.size()
				for i in v.size():
					for k in n:
						if b[i * n + k] == bi and w[i * n + k] > 0.6:
							pts.append(skin.get_bind_pose(bi) * v[i])
			print(mi.name, " hand verts ", pts.size())
			if pts.size() == 0: continue
			var lo := Vector3(1e9, 1e9, 1e9); var hi := -lo; var c := Vector3.ZERO
			for p in pts:
				lo = lo.min(p); hi = hi.max(p); c += p
			print("  centroid ", (c / pts.size()).snapped(Vector3.ONE * 0.01), " min ", lo.snapped(Vector3.ONE * 0.01), " max ", hi.snapped(Vector3.ONE * 0.01))
		# bone axes in model space for a few poses
		var ap := m.get_node("AnimationPlayer") as AnimationPlayer
		for an in ["jimmyidle", "jimmyfullrun", "jimmywalk", "jimmyjumpgun"]:
			if not ap.has_animation(an): continue
			AnimFix.fix(ap.get_animation(an), an); ap.play(an); ap.seek(0.2, true); ap.advance(0.0)
			var xf: Transform3D = m.global_transform.affine_inverse() * sk.global_transform
			var hp: Transform3D = xf * sk.get_bone_global_pose(hb)
			var fa: Vector3 = xf * sk.get_bone_global_pose(sk.get_bone_parent(hb)).origin
			print(an, " hand origin ", hp.origin.snapped(Vector3.ONE * 0.1), " forearm->hand ", (hp.origin - fa).normalized().snapped(Vector3.ONE * 0.01), " bone X ", hp.basis.x.snapped(Vector3.ONE * 0.01), " Y ", hp.basis.y.snapped(Vector3.ONE * 0.01), " Z ", hp.basis.z.snapped(Vector3.ONE * 0.01))
		m.queue_free()
	get_tree().quit()
