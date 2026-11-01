extends Node
class StubWorld extends Node:
	var match_over := false
func _ready() -> void:
	Config.test_mode = true
	for team in [0, 1]:
		var p := Player.new(); p.peer_id = 99; p.team = team; p.world = StubWorld.new()
		var lo := Loadout.default_loadout(); lo["movement"] = &"jetpack"; p.loadout = lo
		add_child(p)
		p.model_yaw = -PI / 2.0
		await get_tree().create_timer(0.5).timeout
		var b := p.jp_attach.global_transform
		var sk := p.jp_attach.get_parent() as Skeleton3D
		print("team ", team, " attach basis x=", b.basis.x.normalized(), " y=", b.basis.y.normalized(), " z=", b.basis.z.normalized(), " origin=", b.origin, " body=", p.global_position)
		var bi := sk.find_bone("Bip01 Spine")
		print("  spine pose origin(skel) ", sk.get_bone_global_pose(bi).origin, " neck ", sk.get_bone_global_pose(sk.find_bone("Bip01 Neck")).origin, " pelvis ", sk.get_bone_global_pose(sk.find_bone("Bip01 Pelvis")).origin)
		var bb := Fx.aabb_of(p.jp_attach.get_child(0).get_child(0) as Node3D)
		print("  jp aabb ", bb)
	get_tree().quit()
