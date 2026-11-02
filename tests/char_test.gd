extends Node3D
## Roster test: every importable character loads as a Player model, every clip faces +X, the right-hand attach point exists, feet sit on the floor,
## evil clones have red eyes. Characters whose art is not imported are reported as locked (not a failure).
## godot --headless --path . res://tests/char_test.tscn      (see tests/run_char_test.sh)
class StubWorld extends Node:
	var match_over := false
	func local_team() -> int:
		return 0

var fails := 0
var player: Player
var rows: Array[String] = []

func check(c: bool, m: String) -> void:
	print("  [", "ok" if c else "FAIL", "] ", m)
	if not c:
		fails += 1

func spawn(id: StringName) -> void:
	if player:
		player.queue_free()
		await get_tree().physics_frame
	player = Player.new()
	player.peer_id = 1
	player.team = Characters.ROSTER[id].team
	player.world = StubWorld.new()
	var lo := Loadout.default_loadout()
	lo["char"] = id
	player.loadout = lo
	player.position = Vector3(0, 0.3, 0)
	add_child(player)
	await get_tree().physics_frame
	player.test_move = Vector2.ZERO
	for i in 30:
		await get_tree().physics_frame
	player.set_physics_process(false)

func glb_of(id: StringName) -> String:
	match Characters.base_of(id):
		&"jimmy": return "jimmy.glb"
		&"negatron": return "nummey_villain.glb"
		var b: return "%s.glb" % b

## forward (xz) of a clip in the model root frame, same convention as AnimFix
func facing(sk: Skeleton3D, a: Animation, root: Node3D) -> Vector3:
	var sk_xf := Transform3D.IDENTITY
	var n: Node = sk
	while n != root and n != null:
		if n is Node3D:
			sk_xf = (n as Node3D).transform * sk_xf
		n = n.get_parent()
	var l := sk_xf * AnimFix._bone_global(sk, a, sk.find_bone("Bip01 L Thigh"), a.length * 0.5).origin
	var r := sk_xf * AnimFix._bone_global(sk, a, sk.find_bone("Bip01 R Thigh"), a.length * 0.5).origin
	var f := (l - r).cross(Vector3.UP)
	f.y = 0.0
	return f.normalized() if f.length() > 1e-6 else Vector3.ZERO

func test_skinned(id: StringName) -> void:
	var m := player.model
	var sk := m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var parts := FootSkin.load_parts(glb_of(id), m)
	var worst := 0.0
	var line := "GAP %-9s" % id
	for role in ["idle", "walk", "run", "jump"]:
		var c: String = {"idle": player.anim_idle, "walk": player.anim_walk, "run": player.anim_run, "jump": player.anim_jump}[role]
		if c == "" or not player.anim.has_animation(c):
			continue
		var a := player.anim.get_animation(c)
		var fw := facing(sk, a, m)
		check(fw.x > 0.7 or fw == Vector3.ZERO, "%s %s faces +X (fwd %s)" % [id, c, fw.snapped(Vector3.ONE * 0.01)])
		m.position.y = FootTable.lift(c) * player.char_k
		player.anim.play(c, 0.0)
		player.anim.advance(a.length * 0.37)
		var ys := []
		for i in 40:
			player.anim.advance(a.length / 41.0)
			var xf := sk.global_transform
			ys.append(xf.origin.y + FootSkin.lowest(sk, parts) * xf.basis.get_scale().y - player.global_position.y)
		ys.sort()
		line += "  %s p10=%+.3f min=%+.3f" % [role, ys[3], ys[0]]
		if role != "jump":
			worst = maxf(worst, absf(ys[3]))
			check(ys[0] > -0.15, "%s %s feet do not sink (min %+.3f m)" % [id, c, ys[0]])
	check(worst < 0.03, "%s feet on the floor (worst p10 gap %.3f m)" % [id, worst])
	rows.append(line)

## Libby: vertex animation, lowest vertex of every morph frame
func test_libby(id: StringName) -> void:
	var line := "GAP %-9s" % id
	var worst := 0.0
	for role in ["idle", "walk", "run"]:
		var rel: String = CharModel.LIBBY[role][0]
		var doc := GLTFDocument.new(); var st := GLTFState.new()
		doc.append_from_file(Config.asset_path(rel), st)
		var im: ImporterMesh = st.get_meshes()[0].mesh
		var ys := []
		for k in im.get_blend_shape_count():
			var d: PackedVector3Array = im.get_surface_blend_shape_arrays(0, k)[Mesh.ARRAY_VERTEX]
			var lo := 1e9
			for v in d: lo = minf(lo, v.y)
			ys.append(lo * Config.WORLD_SCALE * player.char_k + FootTable.lift("libby_" + role) * player.char_k - player.global_position.y)
		ys.sort()
		line += "  %s p10=%+.3f min=%+.3f" % [role, ys[0], ys[0]]
		if role == "idle" or role == "walk":
			worst = maxf(worst, absf(ys[ys.size() - 1]))
	check(worst < 0.03, "%s feet on the floor (idle/walk gap %.3f m)" % [id, worst])
	rows.append(line)
	# facing: the variant meshes carry the yaw fix (Libby natively faces -Z)
	for n in player.model.get_children():
		if n is Node3D and n.name.begins_with("liby"):
			check(is_equal_approx((n as Node3D).rotation.y, CharModel.LIBBY_YAW), "%s mesh %s turned to +X" % [id, n.name])

func red_eyes(id: StringName) -> void:
	var base := Characters.base_of(id)
	var spec: Dictionary = CharModel.EYES[base]
	var changed := 0
	for mi in player.model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		var ov := (mi as MeshInstance3D).get_surface_override_material(0) as BaseMaterial3D
		var orig := mesh.surface_get_material(0) as BaseMaterial3D
		if ov == null or orig == null:
			continue
		var a := ov.albedo_texture.get_image()
		var b := orig.albedo_texture.get_image()
		for e in spec.ell:
			for y in range(e[1] - e[3], e[1] + e[3] + 1):
				for x in range(e[0] - e[2], e[0] + e[2] + 1):
					var ca := a.get_pixel(x, y); var cb := b.get_pixel(x, y)
					if ca.r > ca.g + 0.25 and ca.r > ca.b + 0.25 and not (cb.r > cb.g + 0.25):
						changed += 1
		break
	check(changed >= 20, "%s eyes recoloured red (%d px)" % [id, changed])

## CharacterSelect: team-filtered grid, pick -> SELECT emits the id, locked characters refuse
func select_flow() -> void:
	var cs := CharacterSelect.new()
	cs.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cs)
	var got := []
	cs.chosen.connect(func(id): got.append(id))
	for t in [Config.TEAM_JIMMY, Config.TEAM_NEGATRON]:
		cs.open(t, Characters.default_for_team(t))
		await get_tree().process_frame
		check(cs._cards.size() == Characters.ids_for_team(t).size(), "select screen team %d shows %d cards" % [t, cs._cards.size()])
		var pick: StringName = Characters.ids_for_team(t)[1]
		if Characters.available(pick):
			(cs._cards[pick] as Button).pressed.emit()
			cs._select.pressed.emit()
			check(got.size() > 0 and got[-1] == pick, "pick + SELECT emits %s" % pick)
	Characters.debug_locked = [&"libby"]
	cs.open(Config.TEAM_JIMMY, &"libby")
	check(cs.current == &"jimmy", "a locked character is never preselected")
	cs._pick(&"libby")
	check(cs.current == &"jimmy" and cs._hint.text != "", "locked Libby cannot be picked and shows the hint")
	Characters.debug_locked = []
	cs.queue_free()

## Scooter ultimate: only Negatron himself swaps to his scooter model; everybody else (evil clones included) rides Goddard's scooter as themselves.
## Gear: the jetpack / goof boots attach with the per-character offsets of Characters.GEAR (Libby: pack on the model, no boots).
func gear_checks(id: StringName) -> void:
	var lo := Loadout.from_class(&"blaster")
	lo["char"] = id
	player.set_loadout(lo, 100)
	check(player.model_char == id, "%s keeps its model after a loadout change" % id)
	player.ultimate = UltimateData.get_ultimate(&"goddard_scooter")
	player.set_status("ult", 5.0)
	player._animate()
	var neg := id == &"negatron"
	check(player.model.visible != neg, "%s rider body %s on the scooter ultimate" % [id, "hidden (own scooter model)" if neg else "stays visible"])
	check(player.jim_scooter != null and player.jim_scooter.visible != neg, "%s uses %s scooter" % [id, "Negatron's own" if neg else "Goddard's"])
	check(not (player.scooter_model != null and player.scooter_model.visible) or neg, "%s is not swapped for a Negatron scooter model" % id)
	if not neg and player.anim_scooter != "":
		check(player.anim.has_animation(player.anim_scooter), "%s has a scooter ride clip (%s)" % [id, player.anim_scooter])
	player.status.clear()
	if Characters.base_of(id) != &"libby":
		check(player.boot_ba.size() == 2, "%s has two goof boots on the foot bones" % id)
	var gc := Characters.gear(id)
	lo = Loadout.from_class(&"sky_jockey")
	lo["char"] = id
	player.set_loadout(lo, 100)
	var skinned := Characters.base_of(id) != &"libby"
	check(player.jp_attach != null, "%s has a jetpack attached" % id)
	if player.jp_attach != null:
		check((player.jp_attach is BoneAttachment3D) == skinned, "%s jetpack is on %s" % [id, "the spine bone" if skinned else "the model (no skeleton)"])
		var holder := player.jp_attach.get_child(0) as Node3D
		var want: Transform3D = gc.get("jet", Balance.JETPACK_XF)
		check(holder.transform.is_equal_approx(want), "%s jetpack uses its own offset" % id)

func _ready() -> void:
	Config.test_mode = true
	var fl := MeshInstance3D.new()
	var body := StaticBody3D.new(); body.collision_layer = 1
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(100, 2, 100); cs.shape = sh
	body.add_child(cs); body.position = Vector3(0, -1, 0); add_child(body)
	# server-side roster rules
	check(Characters.sanitize(&"carl", Config.TEAM_NEGATRON) == &"negatron", "a Jimmy-side character is refused on the Negatron team")
	check(Characters.sanitize(&"ecarl", Config.TEAM_NEGATRON) == &"ecarl", "evil Carl is allowed on the Negatron team")
	check(Characters.sanitize("hax", Config.TEAM_JIMMY) == &"jimmy", "unknown ids fall back to the team default")
	check(Loadout.sanitize({"char": "elibby"}, Config.TEAM_JIMMY).char == &"jimmy", "loadout validation drops a wrong-team character")
	check(Loadout.sanitize(Loadout.to_wire({"char": &"cindy"}.merged(Loadout.default_loadout())), Config.TEAM_JIMMY).char == &"cindy", "character survives the wire round trip")
	for id in Characters.ORDER:
		print("== ", id)
		if not Characters.available(id):
			print("  locked: ", Characters.lock_hint(id))
			continue
		await spawn(id)
		check(player.model_char == id, "%s model built (got %s)" % [id, player.model_char])
		check(player.palm != null, "%s has a right-hand attach point" % id)
		if player.palm:
			var d := player.palm.global_position - player.global_position
			check(d.y > 0.2 and d.y < 1.4 and Vector2(d.x, d.z).length() < 0.9, "%s palm %s is near the body" % [id, d.snapped(Vector3.ONE * 0.01)])
		if Characters.base_of(id) == &"libby":
			test_libby(id)
		else:
			test_skinned(id)
		if Characters.is_evil(id):
			red_eyes(id)
		gear_checks(id)
	check(Characters.gear(&"carl") != Characters.gear(&"jimmy"), "Carl has his own gear offsets")
	if Characters.available(&"libby"):
		var lm := CharModel.build(&"libby")
		var lr: Dictionary = lm.get_meta("roles")
		check(lr.jump != "" and lr.fall != "" and lr.fly != "", "Libby has jump / fall / fly fallbacks (%s)" % lr.jump)
		lm.free()
	await select_flow()
	print("\n".join(rows))
	print("CHAR TEST ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
