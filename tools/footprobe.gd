extends Node
## Foot-offset probe: CPU-skins the model for each animation and reports lowest skinned vertex (cm, scaled) + stance foot speed.
## godot --headless --path . res://tools/footprobe.tscn
func _skinned_min(sk: Skeleton3D, parts: Array) -> Dictionary:
	# parts: [{verts, bones, weights, skin}]; returns {y: lowest, p: position}
	var lo := 1e9
	var lp := Vector3.ZERO
	var gp: Array = []
	for i in sk.get_bone_count():
		gp.append(sk.get_bone_global_pose(i))
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
			if ws > 0.0:
				p /= ws
			if p.y < lo:
				lo = p.y; lp = p
	return {"y": lo, "p": lp}

func probe(rel: String, extra_from: String, names: Array) -> void:
	var path := Config.asset_path(rel)
	var doc := GLTFDocument.new(); var st := GLTFState.new()
	doc.append_from_file(path, st)
	var root := doc.generate_scene(st)
	add_child(root)
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
	if extra_from != "":
		var o := Assets.load_scene(extra_from)
		var oap := o.get_node("AnimationPlayer") as AnimationPlayer
		var lib := ap.get_animation_library("")
		for n in names:
			if oap.has_animation(n) and not lib.has_animation(n):
				lib.add_animation(n, oap.get_animation(n).duplicate())
	var parts := []
	var meshes := st.get_meshes()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.skin == null: continue
		for gn in st.get_nodes():
			if gn.mesh >= 0 and gn.resource_name == mi.name:
				var im: ImporterMesh = meshes[gn.mesh].mesh
				for sidx in im.get_surface_count():
					var a := im.get_surface_arrays(sidx)
					if a[Mesh.ARRAY_BONES] != null and a[Mesh.ARRAY_BONES].size() > 0:
						parts.append({"verts": a[Mesh.ARRAY_VERTEX], "bones": a[Mesh.ARRAY_BONES], "weights": a[Mesh.ARRAY_WEIGHTS], "skin": mi.skin})
	var sc := Config.WORLD_SCALE
	var tb := [sk.find_bone("Bip01 R Toe0"), sk.find_bone("Bip01 L Toe0")]
	for an in names:
		if not ap.has_animation(an): continue
		var L := ap.get_animation(an).length
		var n := 60
		var ys := []; var feet := []
		ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
		ap.play(an, 0.0); ap.advance(L * 0.37)
		for i in n:
			ap.advance(L / (n + 1.0))
			ys.append(_skinned_min(sk, parts).y * sc * 100.0)
			var f := []
			for b in tb:
				f.append(sk.get_bone_global_pose(b).origin * sc)
			feet.append(f)
		var sorted := ys.duplicate(); sorted.sort()
		var mean := 0.0
		for y in ys: mean += y
		mean /= n
		var gl := []
		var amax := -1e9; var at := 0.0
		for i in n:
			if ys[i] > amax: amax = ys[i]; at = L * (i + 1.0) / (n + 1.0)
		for i in n - 1:
			var k := 0 if feet[i][0].y < feet[i][1].y else 1
			var d: Vector3 = feet[i + 1][k] - feet[i][k]
			d.y = 0
			gl.append(d.length() / (L / (n + 1.0)))
		var gls := gl.duplicate(); gls.sort()
		var gm := 0.0
		for g in gl: gm += g
		gm /= gl.size()
		print("FOOT %s min=%.2f p10=%.2f mean=%.2f max=%.2f len=%.3f gspeed=%.2f gmean=%.2f airT=%.3f airY=%.2f" % [an, sorted[0], sorted[6], mean, sorted[n - 1], L, gls[gls.size() / 2], gm, at, amax])

func _ready() -> void:
	probe("jimmy.glb", "", ["jimmyidle", "jimmywalk", "jimmyfullrun", "jimmyscooter", "jimmyscooterstop"])
	probe("nummey_villain.glb", "nummey.glb", ["nummeystop", "nummeywalk", "nummeyrun"])
	get_tree().quit()
