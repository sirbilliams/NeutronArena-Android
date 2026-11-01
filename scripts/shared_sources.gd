class_name SharedSources
## Game files shared by the sirbilliams port apps installed on the same Android device (Android plugin "SharedImport",
## android/plugins/sharedimport; the ports expose them through GameFilesProvider). On desktop / without the plugin: nothing.
const SOURCES := [
	{"pkg": "com.sirbilliams.negatron", "game": 2, "name": "Jimmy Neutron vs Jimmy Negatron"},
	{"pkg": "com.sirbilliams.neutron1", "game": 1, "name": "Boy Genius"},
]

static func plugin() -> Object:
	return Engine.get_singleton("SharedImport") if Engine.has_singleton("SharedImport") else null

## One entry per installed port app: {pkg, game, name, status, ok, error}. status: ok | no_game | denied | no_provider.
static func installed() -> Array:
	var out := []
	var p := plugin()
	if p == null: return out
	var st: Dictionary = p.installed_sources()
	for s in SOURCES:
		if not st.has(s["pkg"]): continue
		var e: Dictionary = s.duplicate()
		e["status"] = str(st[s["pkg"]])
		e["ok"] = e["status"] == "ok"
		e["error"] = message(e["status"])
		out.append(e)
	return out

static func message(status: String) -> String:
	match status:
		"denied": return "Android won't let this app read that app's files (they are signed with different keys, e.g. a test build). Use the .iso instead."
		"no_game": return "The game isn't installed in that app yet. Open it and set up the game first, or use the .iso."
		"no_provider": return "That app is too old to share its files. Update it, or use the .iso."
	return ""

## Blocking (run from a Thread): copies the files the converters need into dest. Returns {ok, error}.
static func copy_from(pkg: String, game: int, dest: String) -> Dictionary:
	var p := plugin()
	if p == null: return {"ok": false, "error": "Not available on this device."}
	var r: Dictionary = p.copy_from(pkg, dest, NaImporter.wanted_files(game))
	return r

## {done, total, current} of the running copy.
static func progress() -> Dictionary:
	var p := plugin()
	return p.copy_progress() if p != null else {}
