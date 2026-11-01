class_name FootSkin
extends RefCounted
## CPU skinning of a character glb to find the lowest skinned vertex of the current pose (tools + movement test; not used in play).

## parts for `rel` (glb under the asset dir) matched to the MeshInstance3D skins of `model`
static func load_parts(rel: String, model: Node) -> Array:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(Config.asset_path(rel), st)
	var parts := []
	var meshes := st.get_meshes()
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.skin == null:
			continue
		for gn in st.get_nodes():
			if gn.mesh >= 0 and gn.resource_name == mi.name:
				var im: ImporterMesh = meshes[gn.mesh].mesh
				for s in im.get_surface_count():
					var a := im.get_surface_arrays(s)
					if a[Mesh.ARRAY_BONES] != null and a[Mesh.ARRAY_BONES].size() > 0:
						parts.append({"verts": a[Mesh.ARRAY_VERTEX], "bones": a[Mesh.ARRAY_BONES], "weights": a[Mesh.ARRAY_WEIGHTS], "skin": mi.skin})
	return parts

## lowest skinned vertex y in skeleton space (raw model units) for the skeleton's current pose
static func lowest(sk: Skeleton3D, parts: Array) -> float:
	var lo := 1e9
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
			lo = minf(lo, p.y)
	return lo
