extends Node
## Measures per-character foot lift / ground speed / height / palm for the CharModel roster (paste the output into scripts/foot_table.gd + char_model.gd).
## godot --headless --path . res://tools/charcal.tscn
func _parts(rel: String) -> Dictionary:
	var doc := GLTFDocument.new(); var st := GLTFState.new()
	doc.append_from_file(Config.asset_path(rel), st)
	var meshes := st.get_meshes()
	var by_name := {}
	for gn in st.get_nodes():
		if gn.mesh >= 0:
			by_name[gn.resource_name] = meshes[gn.mesh].mesh
	return by_name

func _skinned(sk: Skeleton3D, parts: Array) -> PackedVector3Array:
	var gp: Array = []
	for i in sk.get_bone_count():
		gp.append(sk.get_bone_global_pose(i))
	var pts := PackedVector3Array()
	for part in parts:
		var skin: Skin = part.skin
		var binds: Array = []
		for j in skin.get_bind_count():
			var bi := skin.get_bind_bone(j)
			if bi < 0:
				bi = sk.find_bone(skin.get_bind_name(j))
			binds.append(gp[bi] * skin.get_bind_pose(j))
		var v: PackedVector3Array = part.verts
		var b: PackedInt32Array = part.bones
		var w: PackedFloat32Array = part.weights
		for i in v.size():
			var p := Vector3.ZERO
			var ws := 0.0
			for k in 4:
				var wk := w[i * 4 + k]
				if wk > 0.0:
					p += (binds[b[i * 4 + k]] * v[i]) * wk
					ws += wk
			pts.append(p / ws if ws > 0.0 else v[i])
	return pts

func skinned(base: String) -> void:
	var m := CharModel.build(StringName(base)) as Node3D
	add_child(m)
	var by_name := _parts("%s.glb" % base)
	var sk := m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := m.get_node("AnimationPlayer") as AnimationPlayer
	var parts := []
	var hand_acc := Vector3.ZERO; var hand_n := 0
	var hb := sk.find_bone("Bip01 R Hand")
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var im: ImporterMesh = by_name.get(mi.name)
		if (mi as MeshInstance3D).skin == null or im == null:
			continue
		for s in im.get_surface_count():
			var a := im.get_surface_arrays(s)
			if a[Mesh.ARRAY_BONES] == null or a[Mesh.ARRAY_BONES].size() == 0:
				continue
			parts.append({"verts": a[Mesh.ARRAY_VERTEX], "bones": a[Mesh.ARRAY_BONES], "weights": a[Mesh.ARRAY_WEIGHTS], "skin": mi.skin})
			# palm: mean of the vertices dominated by the right hand bone, in that bone's space
			var skin: Skin = mi.skin
			var jidx := -1
			for j in skin.get_bind_count():
				var bi := skin.get_bind_bone(j)
				if bi < 0: bi = sk.find_bone(skin.get_bind_name(j))
				if bi == hb: jidx = j
			if jidx >= 0:
				var vv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				for i in vv.size():
					for k in 4:
						if a[Mesh.ARRAY_BONES][i * 4 + k] == jidx and a[Mesh.ARRAY_WEIGHTS][i * 4 + k] > 0.6:
							hand_acc += skin.get_bind_pose(jidx) * vv[i]; hand_n += 1
	print("PALM %s %s (%d verts)" % [base, str(hand_acc / maxf(hand_n, 1)), hand_n])
	var sc := Config.WORLD_SCALE
	var tb := [sk.find_bone("Bip01 R Toe0"), sk.find_bone("Bip01 L Toe0")]
	for role in m.get_meta("roles"):
		var an: String = m.get_meta("roles")[role]
		if an == "" or not ap.has_animation(an): continue
		var L := ap.get_animation(an).length
		var n := 40
		var los := []; var his := []; var feet := []
		var air_y := -1e9; var air_t := 0.0
		ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
		ap.play(an, 0.0); ap.advance(L * 0.37)
		for i in n:
			ap.advance(L / (n + 1.0))
			var pts := _skinned(sk, parts)
			var lo := 1e9; var hi := -1e9
			for p in pts:
				lo = minf(lo, p.y); hi = maxf(hi, p.y)
			los.append(lo * sc); his.append(hi * sc)
			if lo * sc > air_y: air_y = lo * sc; air_t = L * (i + 1.0) / (n + 1.0) + L * 0.37
			var f := []
			for b in tb: f.append(sk.get_bone_global_pose(b).origin * sc)
			feet.append(f)
		var sl := los.duplicate(); sl.sort()
		var gl := []
		for i in n - 1:
			var k := 0 if feet[i][0].y < feet[i][1].y else 1
			var d: Vector3 = feet[i + 1][k] - feet[i][k]; d.y = 0
			gl.append(d.length() / (L / (n + 1.0)))
		gl.sort()
		var hmean := 0.0
		for i in n: hmean += his[i] - los[i]
		print("CAL %s lift=%.4f gs=%.2f height=%.3f len=%.2f airT=%.2f" % [an, -sl[3], gl[gl.size() / 2], hmean / n, L, fposmod(air_t, L)])
	m.queue_free()

func libby() -> void:
	var m := CharModel.build(&"libby") as Node3D
	var sc := Config.WORLD_SCALE
	for role in ["idle", "walk", "run", "wave"]:
		var rel: String = CharModel.LIBBY[role][0]
		var im: ImporterMesh = _parts(rel).values()[0]
		var a := im.get_surface_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var los := []; var his := []
		for k in im.get_blend_shape_count():
			var d: PackedVector3Array = im.get_surface_blend_shape_arrays(0, k)[Mesh.ARRAY_VERTEX]
			var lo := 1e9; var hi := -1e9
			for i in v.size():
				var y := d[i].y   # NORMALIZED blend shapes (mode 0): absolute positions
				lo = minf(lo, y); hi = maxf(hi, y)
			los.append(lo * sc); his.append(hi * sc)
		if role == "walk" or role == "run":
			var line := ""
			for k in im.get_blend_shape_count():
				var d: PackedVector3Array = im.get_surface_blend_shape_arrays(0, k)[Mesh.ARRAY_VERTEX]
				var lo := 1e9; var lp := Vector3.ZERO
				for i in d.size():
					if d[i].y < lo: lo = d[i].y; lp = d[i]
				# average of vertices within 6 units of the lowest (the planted sole)
				var acc := Vector3.ZERO; var cnt := 0
				for i in d.size():
					if d[i].y < lo + 6.0: acc += d[i]; cnt += 1
				var c := acc / cnt
				line += " [k%d sole fwd=%.1f y=%.1f n=%d]" % [k, -c.z, c.y, cnt]
			print("LIBBYSOLE ", role, line)
		los.sort()
		var hm := 0.0
		for i in los.size(): hm += his[i] - los[i]
		print("CAL libby_%s lift=%.4f gs=0.0 height=%.3f shapes=%d (min %.4f max %.4f) mode=%d" % [role, -los[los.size() / 10], hm / los.size(), los.size(), -los[0], -los[-1], im.get_blend_shape_mode()])
	m.free()

func _ready() -> void:
	for b in ["carl", "cindy", "sheen"]:
		skinned(b)
	libby()
	get_tree().quit()
