extends Node
## Autoload "Assets": runtime glb loading from the user's own game export (never in the repo).
var _cache := {}
var _faces := {}   # rel -> {node name: PackedVector3Array} (CPU-side triangles; RenderingServer mesh data is not readable headless)

func load_scene(rel: String) -> Node:
	var path := Config.asset_path(rel)
	if not _cache.has(rel):
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(path, st) != OK:
			push_error("cannot load " + path)
			return null
		_cache[rel] = doc.generate_scene(st)
		_faces[rel] = _extract_faces(st)
	return (_cache[rel] as Node).duplicate()

func faces(rel: String) -> Dictionary:
	return _faces.get(rel, {})

func _extract_faces(st: GLTFState) -> Dictionary:
	var out := {}
	var meshes := st.get_meshes()
	for n in st.get_nodes():
		var mi: int = n.mesh
		if mi < 0:
			continue
		var im: ImporterMesh = meshes[mi].mesh
		var tris := PackedVector3Array()
		for s in im.get_surface_count():
			var arr := im.get_surface_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx == null or idx.size() == 0:
				tris.append_array(v)
			else:
				var base := tris.size()
				tris.resize(base + idx.size())
				for i in idx.size():
					tris[base + i] = v[idx[i]]
		out[n.resource_name] = tris
	return out
